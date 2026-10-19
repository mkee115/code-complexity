# check_corpus_progress.ps1
# Shows how far the corpus harvest has got. Run from the repo root:  .\check_corpus_progress.ps1
# Safe to run at any time; it only reads files and asks GitHub for the token's usage.

$out   = Join-Path $PSScriptRoot "Cyclomatic Complexity Calculator\report_analysis\data\corpus"
$token = Join-Path $PSScriptRoot "Cyclomatic Complexity Calculator\javaparser-complexity-calculator\.token"

function Count-Rows($file) {
    if (-not (Test-Path $file)) { return 0 }
    $n = 0
    # The harvester keeps the file open, so open it read-only with sharing allowed
    $stream = [System.IO.FileStream]::new($file, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $reader = [System.IO.StreamReader]::new($stream)
    while ($null -ne $reader.ReadLine()) { $n++ }
    $reader.Close()
    return [Math]::Max(0, $n - 1)   # minus the header row
}

$running = Get-Process java -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -notmatch "vscode" }
Write-Host ("Harvester running : " + $(if ($running) { "yes (started " + $running[0].StartTime.ToString("HH:mm") + ")" } else { "NO" }))

$log = Join-Path $out "run_log.txt"
if (Test-Path $log) {
    $chunk = Select-String -Path $log -Pattern "Processing chunk" | Select-Object -Last 1
    if ($chunk) { Write-Host ("Current chunk     : " + $chunk.Line.Trim()) }
    $exit = Select-String -Path $log -Pattern "^EXIT" | Select-Object -Last 1
    if ($exit) { Write-Host ("Finished          : " + $exit.Line) }
}

Write-Host ("Repos written     : " + (Count-Rows (Join-Path $out "repos.csv")) + "  (June run: 1,894)")
Write-Host ("Skipped entries   : " + (Count-Rows (Join-Path $out "skipped.csv")))
$cc = Join-Path $out "cc_data.csv"
if (Test-Path $cc) {
    Write-Host ("Methods file size : " + [Math]::Round((Get-Item $cc).Length / 1MB) + " MB  (June run: ~1,070 MB, fewer columns)")
}

if (Test-Path $token) {
    try {
        $t = (Get-Content $token -Raw).Trim()
        $r = Invoke-RestMethod -Uri "https://api.github.com/rate_limit" -Headers @{ Authorization = "Bearer $t" }
        $core = $r.resources.core
        $reset = [DateTimeOffset]::FromUnixTimeSeconds($core.reset).LocalDateTime.ToString("HH:mm")
        Write-Host ("GitHub API calls  : " + ($core.limit - $core.remaining) + " used this hour (limit " + $core.limit + ", resets " + $reset + ")")
    } catch {
        Write-Host "GitHub API calls  : could not check"
    }
}
