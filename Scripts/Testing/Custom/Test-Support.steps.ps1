<#
   Note: Started to add '_' prefix for variables that are referenced in downstream tests

   Dependencies: PowerShell 7
#>


# Setup before each feature
BeforeEachFeature {
  #Install Powershell Module if Needed
  if (Get-Module -ListAvailable -Name "MicrosoftPowerBIMgmt") {
    Write-Host -ForegroundColor Cyan "MicrosoftPowerBIMgmt already installed"
  } else {
    Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -AllowClobber -Force
  }

  #Install SqlServer Powershell Module if Needed
  if (Get-Module -ListAvailable -Name "SqlServer") {
    Write-Host -ForegroundColor Cyan "SqlServer already installed"
  } else {
    Install-Module -Name SqlServer -Scope CurrentUser -AllowClobber -Force
  }
}

AfterEachFeature{
}

##### BACKGROUND #####

#region BACKGROUND steps

Given 'we have access to the DFTest file in the Workspace: "(?<Workspace>[\w\W].*)"'{
  param($Workspace)

  #Check if we are running locally or in a pipeline
  $_IsLocal = $False

  if(${env:BUILD_SOURCEVERSION}) # assumes this only exists in Azure Pipelines
  {
    Write-Host -ForegroundColor Cyan "Running tests in the Azure Pipeline."      

    #Compile Azure Pipeline Settings
    $_Opts = @{
      TenantId = "${env:TENANT_ID}";
      UserName = "${env:PPU_USERNAME}";
      Password = "${env:PPU_PASSWORD}";
      BuildVersion = "${env:BUILD_SOURCEVERSION}";
    }

    #Set Password as Secure String
    $Secret = $_Opts.Password | ConvertTo-SecureString -AsPlainText -Force
    $_Credentials = [System.Management.Automation.PSCredential]::new($_Opts.UserName,$Secret)

    Write-Host ($_Opts | Format-Table | Out-String)          

  }
  else #Running locally
  {  
      $_IsLocal = $True    
  }#end if check for azure pipelines or locally    


  # Load Modules
  if($_IsLocal){
    $WorkingDir = (& pwd)
    Import-Module $WorkingDir\Scripts\Testing\Custom\Write-Issue.psm1 -Force  
  }
  else{
    $WorkingDir = (& pwd)
    Import-Module $WorkingDir/Scripts/Testing/Custom/Write-Issue.psm1 -Force  
  }


  Try{
     #Verify that we have an existing connection
     $_WorkspaceObj = Get-PowerBIWorkspace -Name $Workspace
  }Catch{
      # Assume we must reconnect
      if($_IsLocal){
        $ConnectionResults = Connect-PowerBIServiceAccount
      }
      else{
        $ConnectionResults = Connect-PowerBIServiceAccount -Credential $_Credentials
      }

      $ConnectionResults | Should -Not -BeNullOrEmpty
  }


  # Get Workspace info and
  $_WorkspaceObj = Get-PowerBIWorkspace -Name $Workspace
  $_WorkspaceObj | Should -Not -BeNullOrEmpty

  $DatasetObjs = Get-PowerBIDataset -Workspace $_WorkspaceObj

  # Default to service account
  $_DatasetTestName = "DFTest-ServiceAccount"

  if($_IsLocal) # override with local user name
  {
    $_DatasetTestName = "DFTest-$($env:USERNAME)"
  }

  # Double check that the dataset exists in the workspace
  $_DFTestObj = $DatasetObjs | Where-Object {$_.Name -eq $_DatasetTestName}

  if(-not $_DFTestObj)
  {
      Write-Issue -IsLocal $_IsLocal -Type "error" -Message "Please copy the DFTest Template in this project and publish the report with the name '$($_DatasetTestName)'"
  }

  # Set name
  # NOTE, switch to different endpoint if not in commercial environment
  $_XMLAEndpoint = "powerbi://api.powerbi.com/v1.0/myorg/$($Workspace)"

  $_DFTestObj | Should -Not -BeNullOrEmpty    
}


# Check if we have access to the dataflow
And 'we have access to the Dataflow: "(?<DataflowName>[\w\W].*)"'{
  param($DataflowName)

  # Get Dataflows based on the workspace we are testing in
  $DFObjs = Get-PowerBIDataflow -Workspace $_WorkspaceObj

  # Filter to the one we want to test
  $_DFObjToTest = $DFObjs | Where-Object {$_.Name -eq $DataflowName}

  # Verify we have the dataflow object
  $_DFObjToTest | Should -Not -BeNullOrEmpty
}


# Check if table exists
And 'we have the table called "(?<Table>[\w\W].*)"'{
  param($TableName)

  # Get dataflow
  $ExportDFInJSON = $null

  $ExportDFInJSON = Invoke-PowerBIRestMethod -Method Get -Url "groups/$($_WorkspaceObj.Id.Guid)/dataflows/$($_DFObjToTest.Id.Guid)" 

  # Verify we got the file
  $ExportDFInJson | Should -Not -BeNullOrEmpty

  $_ExportDF = $ExportDFInJSON | ConvertFrom-Json

  $TableCheck = $_ExportDF.entities | Where-Object {$_.name -eq $TableName}

  # Verify table exists in the dataflow
  $TableCheck | Should -Not -BeNullOrEmpty

  # Declare table for the scope of the tests
  $_TableName = $TableName
}


# This will update the parameter of the DFTest dataset and issue a syncrhonous refresh
And 'we can setup the table for testing'{
  #Load Modules
  if($_IsLocal)
  {
      $WorkingDir = (& pwd)
      Import-Module $WorkingDir\Scripts\Testing\Custom\Update-DFTestDatasetParametersWithLocal.psm1 -Force  
      Import-Module $WorkingDir\Scripts\Testing\Custom\Invoke-RefreshDatasetSyncWithLocal.psm1 -Force            
  }
  else
  {
      $WorkingDir = (& pwd) -replace "\\", '/'
      Import-Module $WorkingDir/Scripts/Testing/Custom/Update-DFTestDatasetParametersWithPPU.psm1 -Force
      Import-Module $WorkingDir/Scripts/Testing/Custom/Invoke-RefreshDatasetSyncWithPPU.psm1 -Force
  }


  # Get Run ID
  $_RunID = Get-Variable -Name "DFTest_RunID" -Scope Global -ValueOnly -ErrorAction:Ignore

  # Validate Run ID
  $_RunID | Should -Not -BeNullOrEmpty    

  #Retrieve Parameters Endpoint
  $ParametersUrl = "groups/$($_WorkspaceObj.Id.Guid)/datasets/$($_DFTestObj.Id.Guid)/parameters"

  $DSParameters = Invoke-PowerBIRestMethod -Method Get -Url $ParametersUrl | ConvertFrom-Json

  $RunIDCheck = ($DSParameters.value | Where-Object {$_.name -eq "Run_ID"})

  $DataflowIDCheck = ($DSParameters.value | Where-Object {$_.name -eq "Dataflow_ID"})

  # Check Run ID and Dataflow ID
  $RunIDCheck | Should -Not -BeNullOrEmpty

  $DataflowIDCheck | Should -Not -BeNullOrEmpty

  If($RunIDCheck.currentValue -ne $_RunID -or $DataflowIDCheck.currentValue -ne $_DFObjToTest.Id.Guid){

    Write-Host -ForegroundColor Cyan  "Updating dataflow testing dataset"

    # Issue Refresh
    If($_IsLocal){
      # Issue Update

      $CheckUpdate1 = Update-DFTestDatasetParametersWithLocal -WorkspaceId $_WorkspaceObj.Id.Guid `
                                              -DatasetId $_DFTestObj.Id.Guid `
                                              -DataflowWorkspaceId $_WorkspaceObj.Id.Guid `
                                              -DataflowId $_DFObjToTest.Id.Guid `
                                              -RunId $_RunID  

      $CheckUpdate1 | Should -Be $True

      # Issue Synchronous Refresh
      $CheckUpdate2 = Invoke-RefreshDatasetSyncWithLocal -WorkspaceId $_WorkspaceObj.Id.Guid -DatasetId $_DFTestObj.Id.Guid 

      # Make sure refresh completed
      $CheckUpdate2 | Should -Be "Completed"                                            
    }
    else{

      # Issue Update
      $CheckUpdate1 = Update-DFTestDatasetParametersWithPPU -WorkspaceId $_WorkspaceObj.Id.Guid `
                                              -DatasetId $_DFTestObj.Id.Guid `
                                              -UserName $_Opts.UserName `
                                              -Password $_Opts.Password `
                                              -TenantId $_Opts.TenantId `
                                              -DataflowWorkspaceId $_WorkspaceObj.Id.Guid `
                                              -DataflowId $_DFObjToTest.Id.Guid `
                                              -RunId $_RunID  

      $CheckUpdate1 | Should -Be $True

      # Issue Synchronous Refresh
      $CheckUpdate2 = Invoke-RefreshDatasetSyncWithPPU -WorkspaceId $_WorkspaceObj.Id.Guid `
                                                         -DatasetId $_DFTestObj.Id.Guid `
                                                         -UserName $_Opts.UserName `
                                                         -Password $_Opts.Password `
                                                         -TenantId $_Opts.TenantId `

      # Make sure refresh completed
      $CheckUpdate2 | Should -Be "Completed"  

    }# end is local check
  }
  else{
    Write-Host -ForegroundColor Cyan "Running test without issuing dataset refresh."
  }
  #end run id check
}


##### SCHEMA CHECK #####

# Schema check

# Should be contain or match for the parameter
Then 'it should (?<ContainOrMatch>\S*) the schema defined as follows:'{
param($ContainOrMatch, $Table)

Write-Host -ForegroundColor Cyan "Checking Schema" 

  #Load Modules
  if($_IsLocal)
  {
      $WorkingDir = (& pwd)
      Import-Module $WorkingDir\Scripts\Testing\Custom\Write-Issue.psm1 -Force            
  }
  else
  {
      $WorkingDir = (& pwd) -replace "\\", '/'
      Import-Module $WorkingDir/Scripts/Testing/Custom/Write-Issue.psm1 -Force  
  }

$PassedRowChecks = $True

foreach($Row in $Table)
{
  Write-Host -ForegroundColor Cyan "Checking for $($Row.Name) of $($Row.Type) exists."

  #Check Entity
  $EntityCheck = $_ExportDF.entities | Where-Object -FilterScript {$_.name -ceq $_TableName}
 
  #Write-Host $EntityCheck
  #Check Name and Type
  $Check = $EntityCheck.attributes | Where-Object -FilterScript { $_.name -ceq $Row.Name -and $_.dataType -eq $Row.Type }
  #Write-Host $Check

  if(-not $Check)
  {
      $PassedRowChecks = $False
      Write-Issue -IsLocal $_IsLocal -Type "error" -Message "Checking for $($Row.Name) of $($Row.Type) exists failed."        
  }

}# end foreach

$PassedRowChecks | Should -Be $True

# if 'match' then at this point make sure no additional columns
if($ContainOrMatch -eq 'match')
{
  #Number of Columns should match
  $Table.Count | Should -Be $EntityCheck.attributes.Count
}
}


##### CONTENT CHECK #####
# Row Count Check
# Valid Comparison Values "greater than", "less than", "greater than or equal to", "less than or equal", or "equal to"
Then 'there should be (?<Comparison>(exactly)|(less than)|(less than or equal to)|(greater than)|(greater than or equal to)) (?<ExpectedCount>\d*) records returned'{
  param($Comparison, $ExpectedCount)

  Write-Host -ForegroundColor Cyan "Checking for Row Count" 

  #Convert parameter to integer
  $ExpectedCount = [int]$ExpectedCount

  $ValQuery = "EVALUATE DISTINCT(FILTER(RowCount,[Table Name] = `"$($_TableName)`"))"    

  if($_IsLocal)
  {

    $Result = Invoke-ASCmd -Server $_XMLAEndpoint `
    -Database $_DatasetTestName `
    -Query $ValQuery
  }
  else
  {
    # Build Pipeline
    $Result = Invoke-ASCmd -Server $_XMLAEndpoint `
    -Database $_DatasetTestName `
    -Query $ValQuery `
    -Credential $_Credentials
  }

  #Remove unicode chars for brackets and spaces from XML node names
  $Result = $Result -replace '_x[0-9A-z]{4}_', '';

  #Load into XML and return
  [System.Xml.XmlDocument]$XmlResult = New-Object System.Xml.XmlDocument
  $XmlResult.LoadXml($Result)

  #Get Node List
  [System.Xml.XmlNode]$RowXml = $XmlResult.SelectSingleNode("//*[local-name()='row']")
  # Pull Actual Count from the third column
  $ActualCount = [int]$RowXml.LastChild.InnerXML
  # Handle comparison
  switch ($Comparison)
  {

      "greater than" {$ActualCount | Should -BeGreaterThan $ExpectedCount; Break;}
      "greater than or equal to" {$ActualCount | Should -BeGreaterOrEqual $ExpectedCount; Break;}
      "less than" {$ActualCount | Should -BeLessThan $ExpectedCount; Break;}
      "less than or equal to" {$ActualCount | Should -BeLessOrEqual $ExpectedCount; Break;}  
      "exactly" {$ActualCount | Should -Be $ExpectedCount; Break;}              
  }
}

# Unique Count Check
And 'the values in "(?<ColumnName>[\w\W].*)" are unique'{
param($ColumnName)

#Setup Query
$ValQuery = "EVALUATE SELECTCOLUMNS(DISTINCT(FILTER(DFTest,[Table Name] = `"$($_TableName)`" && [_Column] = `"$($ColumnName)`")),`"_Column`",DFTest[_Column],`"_Value`",DFTest[_Value])"
$RowQuery = "EVALUATE DISTINCT(FILTER(RowCount,[Table Name] = `"$($_TableName)`"))" 

if($_IsLocal)
{

  $RowCountResult = Invoke-ASCmd -Server $_XMLAEndpoint `
  -Database $_DatasetTestName `
  -Query $RowQuery

  $ValuesResult = Invoke-ASCmd -Server $_XMLAEndpoint `
  -Database $_DatasetTestName `
  -Query $ValQuery
}
else
{
  # Build Pipeline
  $RowCountResult = Invoke-ASCmd -Server $_XMLAEndpoint `
  -Database $_DatasetTestName `
  -Query $RowQuery `
  -Credential $_Credentials

  $ValuesResult = Invoke-ASCmd -Server $_XMLAEndpoint `
  -Database $_DatasetTestName `
  -Query $ValQuery `
  -Credential $_Credentials
}

# Check for bad query
$IsBadQuery = $ValuesResult.Contains("<Exception xmlns=`"urn:schemas-microsoft-com:xml-analysis:exception")

if($IsBadQuery)
{
  Write-Issue -IsLocal $_IsLocal -Type "error" -Message "Error when issuing the query: $($ValQuery)"
}

#Run test
$IsBadQuery | Should -Be $false  

#Remove unicode chars for brackets and spaces from XML node names
$RowCountResult = $RowCountResult -replace '_x[0-9A-z]{4}_', '';
$ValuesResult = $ValuesResult -replace '_x[0-9A-z]{4}_', '';  
#Load into XML and return
[System.Xml.XmlDocument]$XmlCountResult = New-Object System.Xml.XmlDocument
$XmlCountResult.LoadXml($RowCountResult)
[System.Xml.XmlDocument]$XmlValuesResult = New-Object System.Xml.XmlDocument
$XmlValuesResult.LoadXml($ValuesResult)

# Validate results
$RowCountResult | Should -Not -BeNullOrEmpty
$ValuesResult | Should -Not -BeNullOrEmpty

#Get Node
[System.Xml.XmlNode]$RowXml = $XmlCountResult.SelectSingleNode("//*[local-name()='row']")
[System.Xml.XmlNodeList]$Values = $XmlValuesResult.GetElementsByTagName("row")

# Pull Row Counts
$RowCount = [int]$RowXml.LastChild.InnerXML
$ValueCount = [int]$Values.Count  

$RowCount | Should -Be $ValueCount
}

# Column Regex
And 'the values of "(?<ColumnName>[a-zA-Z\s].*)" matches this regex: "(?<Regex>[\w\S].*)"' {
param($ColumnName, $Regex)

Write-Host -ForegroundColor Cyan "Checking for $($ColumnName) against regex expression: $($Regex)"
#Load Modules

if($_IsLocal)
{
  $WorkingDir = (& pwd)
  Import-Module $WorkingDir\Scripts\Testing\Custom\Write-Issue.psm1 -Force    
}
else
{
  $WorkingDir = (& pwd) -replace "\\", '/'
  Import-Module $WorkingDir/Scripts/Testing/Custom/Write-Issue.psm1 -Force
}

#Setup Query
$ValQuery = "EVALUATE SELECTCOLUMNS(DISTINCT(FILTER(DFTest,[Table Name] = `"$($_TableName)`" && [_Column] = `"$($ColumnName)`")),`"_Column`",DFTest[_Column],`"_Value`",DFTest[_Value])"

#Connect to Power BI and run DAX Query
if($_IsLocal)
{
  $Result = Invoke-ASCmd -Server $_XMLAEndpoint `
  -Database $_DatasetTestName `
  -Query $ValQuery
}
else
{

  $Result = Invoke-ASCmd -Server $_XMLAEndpoint `
  -Database $_DatasetTestName `
  -Query $ValQuery `
  -Credential $_Credentials
}#end IsLocal check

# Check for bad query
$IsBadQuery = $Result.Contains("<Exception xmlns=`"urn:schemas-microsoft-com:xml-analysis:exception")

if($IsBadQuery)
{
  Write-Issue -IsLocal $_IsLocal -Type "error" -Message "Error when issuing the query: $($ValQuery)"
}

#Run test
$IsBadQuery | Should -Be $false

#Remove unicode chars for brackets and spaces from XML node names
$Result = $Result -replace '_x[0-9A-z]{4}_', '';

#Load into XML and return
[System.Xml.XmlDocument]$XmlResult = New-Object System.Xml.XmlDocument
$XmlResult.LoadXml($Result)

#Get Node List
[System.Xml.XmlNodeList]$Rows = $XmlResult.GetElementsByTagName("row")

if($Rows) #Query got results
{
    $TempVals = @($Rows.LastChild.InnerXML)
    <#Write-Host $Rows.LastChild.InnerXML
    Write-Host $Rows.Count
    Write-Host $Regex#>
    #Get what doesn't match

    if($Rows.Count -gt 0)
    {
      $TempNoMatches = $TempVals -notmatch $Regex

      $TempNoMatches | Format-List
    }
    else
    {
      $TempNoMatches = @() #Empty array because we have nothing to compare to
    }

    #Get Unique Values
    $TempNoMatches = $TempNoMatches | Sort-Object | Get-Unique

    #Increment counter if regex test fails (if got results)
    if($TempNoMatches.Count -gt 0)
    {
        $RegexFailCount +=1
    }

    #Log errors
    foreach($NoMatch in $TempNoMatches)
    {
        # Regex
        Write-Issue -IsLocal $_IsLocal -Type "error" -Message "$($ColumnName) has failed with value '$($NoMatch)' against regex: '$($Regex)'"
    }

    #We should have no mistmatches
    $TempNoMatches.Length | Should -Be 0
}  

#Regex should be present
$Regex | Should -Not -BeNullOrEmpty
}

And 'all tests should pass for the DAX query: "(?<TestFile>[\w\W].*)"'{
  param($TestFile)

  # Grab DAX Files
  if($_IsLocal){
    $DAXFiles = Get-ChildItem -Path ".\Dataflows\$($_DFObjToTest.Name)" -Recurse | Where-Object {$_ -like "*.dax"}  
  }else{
    $DAXFiles = Get-ChildItem -Path "./Dataflows/$($_DFObjToTest.Name)" -Recurse | Where-Object {$_ -like "*.dax"}  
  }

  # Check if file exists
  $DAXCheck = $DAXFiles | Where-Object {$_.BaseName -eq $TestFile}

  # Validate it is not null
  $DAXCheck | Should -Not -BeNullOrEmpty

  #Set Failure count to zero
  $FailureCount = 0
  $Tries = 0
  $NumberofRetries = 0

  # Handle number of retries if build agent has network issues
  if($_IsLocal -eq $false){
    $NumberofRetries = 3
  }

  $Passed = $false
  # Run retry logic due to network issues in the build agent
  do
  {
    $FailureCount = 0

    if ($TestFile) {
      Write-Host -ForegroundColor Cyan "Running Tests within $($TestFile)"
   
      #Connect to Power BI and run DAX Query
      if($_IsLocal)
      {
        $Result = Invoke-ASCmd -Server $_XMLAEndpoint `
        -Database $_DatasetTestName `
        -InputFile $DAXCheck.FullName
      }
      else
      {

        $Result = Invoke-ASCmd -Server $_XMLAEndpoint `
        -Database $_DatasetTestName `
        -InputFile $DAXCheck.FullName `
        -Credential $_Credentials
      }#end IsLocal check

      #Remove unicode chars for brackets and spaces from XML node names
      $Result = $Result -replace '_x[0-9A-z]{4}_', '';

      # Check for bad query
      $IsBadQuery = $Result.Contains("<Exception xmlns=`"urn:schemas-microsoft-com:xml-analysis:exception")

      if($IsBadQuery)
      {
        Write-Issue -IsLocal $_IsLocal -Type "error" -Message "Error when issuing the query: $($ValQuery)"
      }

      #Run test
      $IsBadQuery | Should -Be $false      

      #Load into XML and return
      [System.Xml.XmlDocument]$XmlResult = New-Object System.Xml.XmlDocument
      $XmlResult.LoadXml($Result)

      #Get Node List
      [System.Xml.XmlNodeList]$Rows = $XmlResult.GetElementsByTagName("row")

      #Check if Row Count is 0, no test results.
      if ($Rows.Count -eq 0) {
        $FailureCount += 1
        Write-Issue -IsLocal $_IsLocal -Type "error" -Message "Query in test file $($DAXCheck.FullName) returned no results."
      }#end check of results

      #Iterate through each row of the query results and check test results
      foreach ($Row in $Rows) {
        #Expects Columns TestName, Expected, Actual Columns, Passed
        if ($Row.ChildNodes.Count -ne 4) {
          Write-Issue -IsLocal $_IsLocal -Type "error" -Message "Query in test file $($DAXCheck.FullName) returned no results that did not have 4 columns (TestName, Expected, and Actual, Passed)."
          $FailureCount += 1
          #$Row.ChildNotes.Count | Should -Not -Be 4
        }
        else {
          #Extract Values
          $TestName = $Row.ChildNodes[0].InnerText
          $ExpectedVal = $Row.ChildNodes[1].InnerText
          $ActualVal = $Row.ChildNodes[2].InnerText
          #Compute whether the test passed
          $Passed = ($ExpectedVal -eq $ActualVal) -and ($ExpectedVal -and $ActualVal)

          if (-not $Passed) {
            $FailureCount += 1
            Write-Issue -IsLocal $_IsLocal -Type "error" -Message "FAILED!: Test $($TestName). Expected: $($ExpectedVal) != $($ActualVal)"
          }
          else {
            Write-Host -ForegroundColor Green "Test $($TestName) passed. Expected: $($ExpectedVal) == $($ActualVal)"
          }
        }
      }#end foreach row
    }

    if($_IsLocal -eq $false){
      Write-Host "Tests did not pass first time, try again."
    }    

    $Tries += 1
  }while ($Tries -lt $NumberofRetries)    

  #No failures
  $FailureCount | Should -Be 0
}