<#
    Author: John Kerski
    .SYNOPSIS
        Runs test cases for Power BI files that are opened locally

    .DESCRIPTION
        Runs test cases for Power BI files that are opened locally

        If no parameters are passed all tests will be ran

        Dependencies: PowerShell < 5 so is can run Invoke-AsCmd
    .PARAMETER Dataflow
        The name of the Power BI file
       
        Example:
            -Dataflow RawSourceExample

    .PARAMETER Feature
        The name of the feature file to test

        Example:
            -Feature RawSourceExampleTest

    .EXAMPLE
        ./Run-DFTests.ps1  -Dataflows "RawSourceExample" -Feature "RawSourceExampleTest"
        @("RawSourceExample","RawSourceExample2") | ./Run-DFTests.ps1
    #>
    param(
    [Parameter(Mandatory= $true, ValueFromPipeline = $true)]    
    [String[]]$DataFlows, 
    [Parameter(Mandatory= $false)]
    [String]$Feature)

    #Setup TLS 12
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    #Import Appropriate Modules
    $WorkingDir = (& pwd)
    $IsLocal = $True
    $Slash = "\"

    #Check Powershell version to make sure it's compatible for Invoke-AsCmd
    if($PSVersionTable.PSVersion.Major -lt 7)
    {
        Write-Host -ForegroundColor Red "The current terminal is running the wrong version of Powershell.  Please make sure PowerShell 7 is used."
        return
    }
    else{
        Try{
            #Test Invoke-As Cmd
            Invoke-ASCmd -ErrorAction 'silentlycontinue'
        }Catch{
            #Do Nothing
        }
    }#end PS check
    
    if(${env:BUILD_SOURCEVERSION}) # assumes this only exists in Azure Pipelines
    {
        $IsLocal = $False
        $Slash = "/"
    }

    if(-not $DataFlows)
    {
        Write-Host -ForegroundColor Red "No Dataflows argument was supplied."        
        return
    }

    Import-Module "$($WorkingDir)$($Slash)Scripts$($Slash)Testing$($Slash)Pester$($Slash)4.10.1$($Slash)Pester.psm1" -Force

    foreach($Dataflow in $Dataflows)
    {
        #Setup test file path
        $TestResultsFilePath = "$($WorkingDir)$($Slash)TEST-$((New-Guid).Guid).xml"

        Write-Host -Foreground Cyan "Saving test results to $($TestResultsFilePath)"
    
        # Get Dataflow Files
        $DFFiles = Get-ChildItem -Path ".$($Slash)Dataflows" -Recurse | Where-Object {$_ -like "*.json"}    

        # Check to make sure the FileName exists
        $DFFile = $null
        $TestFeatureFiles = $null
        $ShouldTestOneFeature = $false    

        # Check if Dataflow is supplied
        if(-not $DataFlow)
        {
            Write-Host -ForegroundColor Red "No Dataflow argument was supplied."        
            return
        }
        else {
            # Get Dataflow Files
            $DFFile = $DFFiles | Where-Object {$_.Name -like "$($DataFlow).json" -or $_.Name -like $DataFlowName}

            if(-not $DFFile)
            {
                Write-Host -ForegroundColor Red "$($DataFlow) could not be found in any of the folders under 'Dataflows'. If the filename has spaces, please place within double quotes (ex. ""Sample Model"")."
                return
            }

            #Check if specifc features need to be tested
            if($Feature)
            {    
                $TestFeatureFiles = Get-ChildItem -Path $TestFile.DirectoryName -Filter "$($Feature).feature" -Recurse
    
                if(-not $TestFeatureFiles)
                {
                    Write-Host -ForegroundColor Red "$($Feature).feature could not be found in the directory: $($TestFile.DirectoryName)"
                    return
                }
    
                #Change flag to make sure we test one feature
                $ShouldTestOneFeature = $true
            }
            else {
                $TestFeatureFiles = Get-ChildItem -Path $TestFile.DirectoryName -Filter "*.feature" -Recurse
            }
        }#end FileName check
    
        #Rest failed test case count
        $FailedTestCases = 0

        if($ShouldTestOneFeature -eq $true)
        {
            #Assign to Feature File to test
            $FolderPathToTest = $TestFeatureFiles.VersionInfo.FileName
        }
        else
        {
            #Assign directory of feature files to test
            $FolderPathToTest = "Dataflows$($Slash)$($Dataflow)"
        }# end check which feature files to test
    
        #Check if current project has a pbi folder for the opened Dataflow file in desktop
        if (Test-Path -Path $FolderPathToTest) {
            Write-Host -Foreground Cyan "Running Tests for Dataflow: $($Dataflow)"

            #Setup Test Guid
            $TestGuid = (New-Guid).Guid
            Write-Host -Foreground Cyan "Unique Identifer for this test run: $($TestGuid)"
            Remove-Variable -Name "DFTest_RunID" -Scope Global -ErrorAction:Ignore
            New-Variable -Name "DFTest_RunID" -Value $TestGuid -Scope Global -Force

            #Now run tests
            Invoke-Gherkin -Strict -Path $FolderPathToTest -OutputFile $TestResultsFilePath -OutputFormat NUnitXml -Show  Failed,Summary,Context

            #Load into XML
            [System.Xml.XmlDocument]$TempResult = Get-Content $TestResultsFilePath
            $TempFailureCount = [int]$TempResult.'test-results'.failures
    
            $FailedTestCases += $TempFailureCount + 0

            #Display Failed Cases
            $FailedXml = Select-Xml -Path $TestResultsFilePath -XPath "//test-case[@result='Failure']"

            if($TempFailureCount -ne 0)
            {
            Write-Host -ForegroundColor Red "The following are the failed test case(s) for $($Temp.Title):"
            $FailedOutput = $FailedXml.Node | Select-Object name

            # Output list of failures
            $X = 1
            foreach($F in $FailedOutput){
            Write-Host -ForegroundColor Red "$X) $($F.name) `n"
            $X +=1
            }#end foreach
            }
    
        }#end if
    
        #Output results
        if ($TestFeatureFiles.Length -eq 0)
        {
            Write-Host -ForegroundColor Yellow "WARNING:  No test cases ran for $($DataFlow)"
        }
        elseif ($FailedTestCases -eq 0) {
            Write-Host -ForegroundColor Green "SUCCESS: All test cases passed for $($DataFlow)"
        }
        else {
            Write-Host -ForegroundColor Red "Failed: $($FailedTestCases) test case(s) failed for $($DataFlow)"
        }#end check number of failures
    }#end for each

    if($IsLocal){
        #Clean up test results locally
        Get-ChildItem -Path "$($WorkingDir)$($Slash)" "TEST-*.xml" | ForEach-Object { Remove-Item -Path $_.FullName}
    }