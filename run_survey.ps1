# run_survey.ps1
# Builds the calculator then prints all complexity metrics for every method in survey_code.java.
# Run from the repo root:  .\run_survey.ps1

$mvnCmd  = (Get-ChildItem "$env:USERPROFILE\.m2\wrapper\dists\apache-maven-3.9.11" -Recurse -Filter "mvn.cmd").FullName
$base    = Join-Path $PSScriptRoot "Cyclomatic Complexity Calculator\javaparser-complexity-calculator"
$pom     = Join-Path $base "pom.xml"
$survey  = Join-Path $PSScriptRoot "survey_code.java"

Write-Host "Building..."
& $mvnCmd -f $pom package dependency:copy-dependencies -DskipTests -q
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed"; exit 1 }

Write-Host "Analysing $survey`n"
$cp = "$base\target\classes;$base\target\dependency\*"
& java -cp $cp com.complexity.SurveyAnalyser $survey
