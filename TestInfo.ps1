param($testXMLFile = "C:\Temp\TestsResults.xml")

$testResult = [xml](Get-Content -Path $testXMLFile)

$script:unitTestCount = 0
$script:unitTotalTime = 0.0

$script:integrationTestCount = 0
$script:integrationTestTotalTime = 0.0

Function Invoke-RecurseTestResults($testSuite) {
  $testSuite.results.ChildNodes | % {
    $item = $_
    $localName = $item.LocalName
    switch ($localName) {
      'test-suite' { Invoke-RecurseTestResults -TestSuite $item;  }
      'test-case' {
        if ($item.executed -eq $true) {
          if ($item.name -match 'Integration') {
            $script:integrationTestCount++
            $script:integrationTestTotalTime = $script:integrationTestTotalTime + $item.time
          } else {
            $script:unitTestCount++
            $script:unitTotalTime = $script:unitTotalTime + $item.time
          }
        }
        break
      }
      default {
        Write-Host "Unknown name $localName"
      }
    }
  }
}

Invoke-RecurseTestResults -TestSuite ($testResult.'test-results'.'test-suite')

Write-Host "unitTestCount = $unitTestCount"
Write-Host "unitTotalTime = $unitTotalTime"
Write-Host ""
Write-Host "integrationTestCount = $integrationTestCount"
Write-Host "integrationTestTotalTime = $integrationTestTotalTime"
