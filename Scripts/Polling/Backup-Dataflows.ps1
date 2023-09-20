<#
    Author:  John Kerski

    Description:  Backups Power BI Dataflows to Azure DevOps repo
#>
# Import Modules
Import-Module "./Scripts/Polling/Add-FileToAzureDevOpsRepo.psm1" -Force
Import-Module "./Scripts/Polling/Get-FileFromAzureDevOpsRepo.psm1" -Force
Import-Module "./Scripts/Polling/Format-Json.psm1" -Force

#Install Powershell Module if Needed
if (Get-Module -ListAvailable -Name "MicrosoftPowerBIMgmt") {
    Write-Host "MicrosoftPowerBIMgmt already installed"
} else {
    Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -AllowClobber -Force
}

# Bring Environment Variables
$BranchName = "${env:BUILD_SOURCEBRANCHNAME}"
Write-Host "Branch Name: $($BranchName)"

$Opts = @{
    TenantId = "${env:TENANT_ID}";
    UserName = "${env:PPU_USERNAME}";
    Password = "${env:PPU_PASSWORD}";
    PATToken = "${env:PAT_TOKEN}";
    APIHost = "${env:API_HOST}";
    OrganizationName = "${env:ORGANIZATION_NAME}";
    ProjectName = "${env:PROJECT_NAME}";
    RepositoryName = "${env:REPOSITORY_NAME}";
    DevGroupId = "${env:PBI_DEV_WS_ID}";
    TestGroupId = "${env:PBI_TEST_WS_ID}";
    ProdGroupId = "${env:PBI_PROD_WS_ID}";
}
# Output to console
$Opts | Format-List

Write-Host "Polling Dataflows to save to the $($BranchName) branch."

# Set which workspace to poll
$WorkspaceId = $Opts.DevGroupId

# Identify which workspace to poll
Switch($BranchName){
    "main" {
        $WorkspaceId = $Opts.ProdGroupId
    }
    "test" {
        $WorkspaceId = $Opts.TestGroupId
    }
    "development" {
        $WorkspaceId = $Opts.DevGroupId
    }
    default {
        $WorkspaceId = $Opts.DevGroupId
    }
}# End Switch

#Set Client Secret as Secure String
$Secret = $Opts.Password | ConvertTo-SecureString -AsPlainText -Force
$Credentials = [System.Management.Automation.PSCredential]::new($Opts.UserName,$Secret)

#Connect to Power BI
$ConnectionStatus = Connect-PowerBIServiceAccount -Credential $Credentials

# Extract Dataflows from the workspace
$DFs = @(Get-PowerBIDataflow -WorkspaceId $WorkspaceId)

# Iterate thru list now and make sure to update repo when timestamps doesn't exist or mismatch
foreach($DF in $DFs)
{
    Try{
        # Add break for logging
        Write-Host " "
        Write-Host "----------------------"
        Write-Host " "
        Write-Host "Checking $($DF.Name) in the repository."
        # Get dataflow from workspace
        $ExportDFInJSON = $null
        $ExportDFInJSON = Invoke-PowerBIRestMethod -Method Get -Url "/groups/$($WorkspaceId)/dataflows/$($DF.Id.Guid)"
        $ExportDF = $ExportDFInJSON | ConvertFrom-Json
        # Format the JSON to be easier to read (prettify)
        $ExportDFInFormattedJSON = Format-Json $ExportDFInJSON            

        # Check Azure DevOps for File
        $TempItem = Get-FileFromAzureDevOpsRepo -ADOAPIHost $Opts.APIHost `
                                                -OrganizationName $Opts.OrganizationName `
                                                -ProjectName $Opts.ProjectName `
                                                -RepositoryName $Opts.RepositoryName `
                                                -AccessToken $Opts.PATToken `
                                                -BranchName "$($BranchName)" `
                                                -Path "Dataflows/$($DF.Name)/$($DF.Name).json"                                                  

        # if it exists then we check if we need to update
        if($TempItem){
            # Check Times are equal
            if(!($TempItem.modifiedTime -eq $ExportDF.modifiedTime))
            {
                Write-Host "$($DF.Name) has been updated, committing dataflow to repository branch $($BranchName)."
                # Save
                Add-FileToAzureDevOpsRepo -ADOAPIHost $Opts.APIHost `
                                            -OrganizationName $Opts.OrganizationName `
                                            -ProjectName $Opts.ProjectName `
                                            -RepositoryName $Opts.RepositoryName `
                                            -AccessToken $Opts.PATToken `
                                            -BranchName "$($BranchName)" `
                                            -Path "Dataflows/$($DF.Name)/$($DF.Name).json" `
                                            -Content $ExportDFInFormattedJSON `
                                            -CommitMessage "Updating $($DF.Name): $($ExportDF.modifiedTime)"
            }# end if
        }
        else{ # new file to add
                Write-Host "$($DF.Name) has been added, committing dataflow to repository branch $($BranchName)."
                # Save
                Add-FileToAzureDevOpsRepo -ADOAPIHost $Opts.APIHost `
                                            -OrganizationName $Opts.OrganizationName `
                                            -ProjectName $Opts.ProjectName `
                                            -RepositoryName $Opts.RepositoryName `
                                            -AccessToken $Opts.PATToken `
                                            -BranchName "$($BranchName)" `
                                            -Path "Dataflows/$($DF.Name)/$($DF.Name).json" `
                                            -Content $ExportDFInFormattedJSON `
                                            -CommitMessage "Adding $($DF.Name): $($ExportDF.modifiedTime)"                
        }#end if
    }Catch [System.Exception]{
        $ErrObj = ($_).ToString()
        Write-Host "##vso[task.logissue type=error]$($ErrObj)"
    }# end try
}# end foreach