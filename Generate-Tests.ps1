<#
    Author: John Kerski
    .SYNOPSIS
        Generate Feature files for testing
        Depends on Power BI PowerShell library

    .DESCRIPTION
        Generate Feature files for testing

    .PARAMETER Workspace
        The name of the Power BI Workspace
       
        Example:
            -Workspace SharedWorkspace        

    .PARAMETER Dataflow
        The name of the Power BI Dataflow
       
        Example:
            -Dataflow Sample

    .PARAMETER Table
        The name of the table in the dataflow
       
        Example:
            -Table RawTable            

    .EXAMPLE
        ./Generate-Tests.ps1 -Workspace "Workspace Name" -Dataflow "Sample Dataflow" -Table "Table Name"
    #>
    param(
    [Parameter(Mandatory= $true)]    
    [String]$Workspace, 
    [Parameter(Mandatory= $true)]
    [String]$Dataflow,
    [Parameter(Mandatory= $true)]
    [String]$Table
    )    

    #Setup TLS 12
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    #Install Powershell Module if Needed
    if (Get-Module -ListAvailable -Name "MicrosoftPowerBIMgmt") {
        Write-Host -ForegroundColor Cyan "MicrosoftPowerBIMgmt already installed"
    } else {
        Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -AllowClobber -Force
    }

    #Import Appropriate Modules
    $WorkingDir = (& pwd)
   
    # Get Dataflow File
    $DFFile = Get-ChildItem -Path "./Dataflows/$($Dataflow)" -Recurse | Where-Object {$_ -like "*.json"}      

    # Run Check
    if(-not $DFFile)
    {
        Write-Host -ForegroundColor Red "$($FileName) could not be found in any of the folders under 'Dataflows'. If the filename has spaces, please place within double quotes (ex. ""Sample Model"")."
        return
    }
    #end check

    Try{
        #Verify that we have an existing connection
        $WorkspaceObj = Get-PowerBIWorkspace -Name $Workspace
     }Catch{
           $ConnectionResults = Connect-PowerBIServiceAccount
           $WorkspaceObj = Get-PowerBIWorkspace -Name $Workspace
     }

    if(-not $WorkspaceObj){
        Write-Host -ForegroundColor Red "$($Workspace) could not be found."        
    }

    # Get Dataflows based on the workspace we are testing in
    $DFObjs = Get-PowerBIDataflow -Workspace $WorkspaceObj

    # Filter to the one we want to test
    $DFObjToTest = $DFObjs | Where-Object {$_.Name -eq $Dataflow}

    if(-not $DFObjToTest){
        Write-Host -ForegroundColor Red "$($Dataflow) could not be found." 
        return      
    }    

    # Get dataflows info
    $ExportDFInJSON = Invoke-PowerBIRestMethod -Method Get -Url "groups/$($WorkspaceObj.Id.Guid)/dataflows/$($DFObjToTest.Id.Guid)" 
    $ExportDF = $ExportDFInJSON | ConvertFrom-Json

    $TableToTest = $ExportDF.entities | Where-Object {$_.name -eq $Table}

    if(-not $TableToTest){
        Write-Host -ForegroundColor Red "$($Table) could not be found."  
        return      
    }  

    # Set output

    # Remove special characters
    $FileName = $Table -replace '_*(\[.*?\]|\(.*?\))_*' -replace '_+', ' '
    $FileName = $Table -replace ' ', ''

    # Test if directories exists, if not create
    if((Test-Path "$($DFFile.DirectoryName)\CI") -eq $False){
        New-Item -ItemType Directory -Force -Path "$($DFFile.DirectoryName)\CI"
    }

    if((Test-Path "$($DFFile.DirectoryName)\Feature") -eq $False){
        New-Item -ItemType Directory -Force -Path "$($DFFile.DirectoryName)\CI\Feature"
    }

    if((Test-Path "$($DFFile.DirectoryName)\$($WorkspaceObj.Id.Guid)") -eq $False){
        New-Item -ItemType Directory -Force -Path "$($DFFile.DirectoryName)\CI\Feature\$($WorkspaceObj.Id.Guid)"
    }

    # Set Output
    $Output_TemplatePath = "$($DFFile.DirectoryName)\CI\Feature\$($WorkspaceObj.Id.Guid)\$($FileName).feature"
    $Output_StepsPath = "$($DFFile.DirectoryName)\CI\Feature\$($WorkspaceObj.Id.Guid)\$($FileName).steps.ps1"    

    # Test output doesn't exist already, if it does rename
    if((Test-Path $Output_TemplatePath) -eq $True){
        $FileName = "$($FileName)$((New-Guid).Guid)"
        $Output_TemplatePath = "$($DFFile.DirectoryName)\CI\Feature\$($WorkspaceObj.Id.Guid)\$($FileName).feature"
        $Output_StepsPath = "$($DFFile.DirectoryName)\CI\Feature\$($WorkspaceObj.Id.Guid)\$($FileName).steps.ps1"        
    }

    # Get Contents of Template
    $TemplateContent = Get-Content -Path ".\Scripts\Testing\Templates\Feature.template"
    $StepsContent = Get-Content -Path ".\Scripts\Testing\Templates\Steps.template"

    # Replace placeholders in template
    $TemplateContent = $TemplateContent -replace '{WORKSPACE}', $Workspace
    $TemplateContent = $TemplateContent -replace '{DATAFLOW}', $Dataflow
    $TemplateContent = $TemplateContent -replace '{TABLE}', $Table

    # Write Filled Out Template to model's folder
    Out-File -FilePath $Output_TemplatePath -Force -InputObject $TemplateContent
    Out-File -FilePath $Output_StepsPath -Force -InputObject $StepsContent    

    Write-Host -ForegroundColor Green "Test File created at $($Output_TemplatePath)"