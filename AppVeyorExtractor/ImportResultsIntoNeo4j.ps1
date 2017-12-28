# Requires PSAppVeyor module
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

$rootPath = $PSScriptRoot

$ReportPath = Join-Path $rootPath 'reports'
If (-Not (Test-Path -path $ReportPath)) { New-Item -Path $ReportPath -ItemType Directory | Out-Null }

# Import DLLs
Add-Type -Path "$PSScriptRoot\nuget\Neo4j.Driver.1.0.2\lib\dotnet\Neo4j.Driver.dll"
Add-Type -Path "$PSScriptRoot\nuget\rda.SocketsForPCL.1.2.2\lib\net45\Sockets.Plugin.Abstractions.dll"
Add-Type -Path "$PSScriptRoot\nuget\rda.SocketsForPCL.1.2.2\lib\net45\Sockets.Plugin.dll"

Function Invoke-Cypher($query, $params = @{}) {
  $queryparams = New-Object 'System.Collections.Generic.Dictionary[[String],[Object]]'

  $params.GetEnumerator() | % {
    $queryparams.Add($_.Key, $_.Value)
  }

  $session.Run($query, $queryparams)
}

$authToken = [Neo4j.Driver.V1.AuthTokens]::Basic('neo4j','Password1')

$dbDriver = [Neo4j.Driver.V1.GraphDatabase]::Driver("bolt://localhost:7687",$authToken)
$session = $dbDriver.Session()

# Kill everything ...
$result = Invoke-Cypher("MATCH ()-[r]-() DELETE r")
$result = Invoke-Cypher("MATCH (n) DELETE n")


$numFolders = (Get-ChildItem -Path $reportPath | Measure-Object).Count
$folderNum = 0
# Import Builds
Get-ChildItem -Path $reportPath | % {
  $folderNum++
  Write-Progress -Id 1 -Activity "Importing Builds" -PercentComplete ($folderNum / $numFolders * 100)
  $BuildVersion = $_.Name
  $testFile = Join-Path $_.Fullname 'tests.json'

  If (Test-Path $testFile) {
    $testData = (Get-Content $testFile | ConvertFrom-Json)
    if ($testData.total -gt 0) {
      Invoke-Cypher("CREATE (:Build { version:'$BuildVersion'})")

      $numtest = 0
      Write-Host ($BuildVersion + " $($testdata.total)")
      $testdata.list | % {
        $numtest++
        Write-Progress -Id 2 -ParentId 1 -Activity "Importing $BuildVersion" -Status 'Tests' -PercentComplete ($numtest / $testdata.list.count * 100)
        $test = $_
        $params = @{
          'testname' = $test.name;
          'testfile' = $test.filename;
        }
        $cypher = "MATCH (b:Build { version:'$BuildVersion'})`n" + `
                  "MERGE (t:Test { name:`$testname, filename:`$testfile})`n" + `
                  "CREATE (b)-[r:TEST_$($test.outcome.ToUpper())]->(t)`n" + `
                  "  SET r.duration = $($test.duration)`n" + `
                  "  SET r.created = '$($test.created)'`n"
        Invoke-Cypher -query $cypher -Params $params
      }
    }
  }
}