$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Note - Requires posh-git

$rootPath = 'C:\source\PSSummit2018\TestProfiler' # $PSScriptRoot

$GitRepoURL = 'https://github.com/PowerShell/xNetworking.git'
$GitPath = Join-Path $rootPath 'gitrepo'
$GitCommitList = Join-Path $rootPath 'commitlist.txt'

$ReportPath = Join-Path $rootPath 'reports'

If (-Not (Test-Path -path $GitPath)) {
  Write-Verbose "Cloning the Repository..."
  & git clone $GitRepoURL $GitPath
  Push-Location $GitPath
  # TODO Use native git, not posh-git
  if ((Get-GitStatus).Branch -ne 'master') {
    Write-Verbose "Checking out master..."
    & git fetch origin
    & git checkout --track origin/master
  }

  # Output the commit list (last 1000 commits should be enough...)
  (& git rev-list HEAD -n 1000) | Set-Content -Path $GitCommitList
  Pop-Location
}

# Time to process each commit
If (-Not (Test-Path -path $ReportPath)) {
  New-Item -Path $ReportPath -ItemType Directory | Out-Null
}

$numCommits = (Get-Content $GitCommitList | Measure-Object).Count

$commitNumber = 1
Get-Content $GitCommitList | ForEach-Object {
  $commitID = $_
  Write-Progress -Activity "Parsing Commits" -Status "Parsing $commitID" -PercentComplete ($commitNumber/$numCommits*100)
  Write-Verbose "Processing $commitID ..."

  $commitDir = Join-Path $ReportPath $commitID
  $reportFile = Join-Path $commitDir 'report.xml'
  If (-Not (Test-Path -path $commitDir)) { New-Item -Path $commitDir -ItemType Directory | Out-Null }

  if (-Not (Test-Path $reportFile)) {
    Push-Location $GitPath
    # Generate the files modified list
    $filesModified = (& git show --oneline --name-only $commitID) | ? { $_ -ne ''} | Select -Skip 1

    if ($filesModified.Count -gt 0) {
      # Output the file list
      $filesModified | Set-Content -Path (Join-Path $commitDir 'filelist.txt')
      # Reset the git repo
      & git reset --hard $commitID
      # Run Pester
      Start-Process -FilePath 'powershell.exe' -ArgumentList @( (Join-Path $rootPath 'RunTests.ps1'), '-Commit', $commitID) -Wait -NoNewWindow:$false | Out-Null
    } else {
      Write-Host "$commitID has no files changed.  Probably a merge commit.  Ignoring"
      "" | Set-Content -Path $reportFile
    }
    Pop-Location
  }

  $commitNumber++
}
