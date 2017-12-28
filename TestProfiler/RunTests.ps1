param($CommitID = '')

if ($CommitID -eq '') { Throw "Need a -CommitID!" }
$VerbosePreference = 'Continue'

Write-Host "Running tests for $CommitID"
$rootPath = $PSScriptRoot
$ReportPath = Join-Path $rootPath 'reports'
$commitDir = Join-Path $ReportPath $commitID
$reportFile = Join-Path $commitDir 'report.xml'

$GitPath = Join-Path $rootPath 'gitrepo'

Set-Location $GitPath
Import-Module '.\Tests\TestHarness.psm1'

Invoke-TestHarness -TestResultsFile $reportFile | Out-Null
