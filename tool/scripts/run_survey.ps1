# run_survey.ps1
# Builds the calculator then prints all complexity metrics for every survey snippet,
# and writes one row per snippet to snippet_metrics.csv.
# Run from the repo root:  tool/scripts/run_survey.ps1

$mvnCmd  = (Get-ChildItem "$env:USERPROFILE\.m2\wrapper\dists\apache-maven-3.9.11" -Recurse -Filter "mvn.cmd").FullName
$base    = Split-Path $PSScriptRoot -Parent
$root    = Split-Path $base -Parent
$pom     = Join-Path $base "pom.xml"
$snips   = Join-Path $root "snippets"
$survey  = Join-Path $snips "survey_code.java"
$csv     = Join-Path $snips "snippet_metrics.csv"

Write-Host "Building..."
& $mvnCmd -f $pom package dependency:copy-dependencies -DskipTests -q
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed"; exit 1 }

Write-Host "Analysing $survey`n"
$cp = "$base\target\classes;$base\target\dependency\*"
& java -cp $cp com.complexity.SurveyAnalyser $survey --csv $csv
