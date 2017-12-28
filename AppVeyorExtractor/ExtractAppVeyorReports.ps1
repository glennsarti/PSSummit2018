# Requires PSAppVeyor module
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$token = 'NOYB'

$rootPath = $PSScriptRoot

$ReportPath = Join-Path $rootPath 'reports'
If (-Not (Test-Path -path $ReportPath)) { New-Item -Path $ReportPath -ItemType Directory | Out-Null }

$AccountName = 'Powershell'
$ProjectName = 'xnetworking'

# Setup auth
$apiUrl = 'https://ci.appveyor.com/api'

$headers = @{
    'Authorization' = "Bearer $token"
    'Content-type' = 'application/json'
}

# Appveyor API Helpers...
Function Get-LastXBuilds($numBuilds, $fromBuildID = '') {
  $uri = "${apiUrl}/projects/${AccountName}/${ProjectName}/history?recordsNumber=${numBuilds}"
  if ($fromBuildID -ne '') {
    $uri = $uri + "&startBuildID=${fromBuildID}"
  }
  $result = Invoke-RestMethod -URI $uri -Method Get -Headers $headers -Verbose:$false

  Write-Output $result
}

Function Get-BuildFromVersion($buildVersion) {
  $uri = "${apiUrl}/projects/${AccountName}/${ProjectName}/build/${buildVersion}"
  $result = Invoke-RestMethod -URI $uri -Method Get -Headers $headers -Verbose:$false

  Write-Output $result
}

Function Get-TestsFromJob($jobID) {
  $uri = "${apiUrl}/buildjobs/${jobID}/tests"
  $result = Invoke-RestMethod -URI $uri -Method Get -Headers $headers -Verbose:$false

  Write-Output $result
}

Function Invoke-DownloadAppVeyorFile($jobID, $remotefilename, $localfilename) {
  # $uri = "${apiUrl}/buildjobs/${jobId}/artifacts"
  # $result = Invoke-RestMethod -URI $uri -Method Get -Headers $headers -OutFile $localfilename -Verbose:$false


  $uri = "${apiUrl}/buildjobs/${jobId}/artifacts/${remotefilename}"
  $result = Invoke-RestMethod -URI $uri -Method Get -Headers $headers -OutFile $localfilename -Verbose:$false
}

$lastBuildID = ''
$keepLooping = $true
$buildBatch = 10
while ($keepLooping) {
  $result = Get-LastXBuilds -NumBuilds $buildBatch -FromBuildID $lastBuildID
  $result.builds | % {
    $thisBuild = $_
    $buildversion = $thisBuild.version
    Write-Host "Processing Build v${buildversion} ($($thisBuild.BuildID))"

    $buildResult = Get-BuildFromVersion($buildversion)

    $buildPath = Join-Path $ReportPath $buildversion
    If (-Not (Test-Path -path $buildPath)) { New-Item -Path $buildPath -ItemType Directory | Out-Null }
    ($buildResult | ConvertTo-JSON -Depth 10) | Set-Content (Join-Path $buildPath 'build.json')

    $thisJob = $buildResult.build.jobs[0]
    $jobID = $thisJob.JobID

    $tests = Get-TestsFromJob $jobID
    ($tests | ConvertTo-JSON -Depth 10) | Set-Content (Join-Path $buildPath 'tests.json')

    try {
      Invoke-DownloadAppVeyorFile -jobID $jobID -remotefilename 'TestsResults.xml' -localfilename (Join-Path $buildPath 'TestsResults.xml')
    } catch {
      Write-Host "Whoops!"
    }
  }
  $keepLooping = ($result.builds.Count -eq $buildBatch)
  $lastBuildID = ($result.builds | Select -Last 1).BuildId
}
