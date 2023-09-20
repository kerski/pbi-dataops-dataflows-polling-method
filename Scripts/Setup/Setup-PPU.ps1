<#
    Author: John Kerski
    Description: This script installs the the polling method for version control and testing for the Power BI Dataflows (Gen 1)

    Dependencies: 
    1) Azure CLI installed and Azure DevOps extension (az extension add --name azure-devops)
    2) Service User must be created beforehand.
    3) Person running the script must have the ability admin rights to Power BI Tenant and at least a Pro license
    4) An existing Azure DevOps instance
#>

#Set Variables
$WSName = Read-Host "Please enter the name of the workspace (ex. Development)"
$SvcUser = Read-Host "Please enter the email address (UPN) of the service account assigned premium per user"

#Get Password and convert to plain string
$SecureString = Read-Host "Please enter the password for the service account assigned premium per user" -AsSecureString
$Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
$SvcPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Bstr)

$ProjectName = Read-Host "Please enter the name of the Azure DevOps project you'd like to create"
$RepoName = $ProjectName
$AzDOHostURL = "https://dev.azure.com/"
$PBIAPIURL = "https://api.powerbi.com/v1.0/myorg"
$RepoToCopy = "https://github.com/kerski/pbi-dataops-dataflows-polling-method.git"
$PipelineName = "dataflow-backup $($WSName)"

#Check Inputs
if(!$WSName -or !$SvcUser -or !$SvcPwd -or !$ProjectName)
{
    Write-Error "Please make sure you entered all the required information. You will need to rerun the script."
    return
} 

if (Get-Module -ListAvailable -Name "MicrosoftPowerBIMgmt") {
    Write-Host "MicrosoftPowerBIMgmt installed moving forward"
} else {
    #Install Power BI Module
    Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -AllowClobber -Force
}

if (Get-Module -ListAvailable -Name "Az.Accounts") {
    Write-Host "Az.Accounts installed moving forward"
} else {
    Write-Host "Installing Azure Powershell Module"
    #Install Az.Accounts
    Install-Module -Name Az -Repository PSGallery -Force -Scope CurrentUser -AllowClobber
}

#Login into Power BI to Create Workspaces
Login-PowerBI

Write-Host -ForegroundColor Cyan "Step 1 or 6: Creating Power BI Workspace" 

#Get Premium Per User Capacity as it will be used to assign to new workspace
$Cap = Get-PowerBICapacity -Scope Individual | Where-Object {$_.DisplayName -like "Premium Per User*"}

if(!$Cap.DisplayName -like "Premium Per User*")
{
    Write-Error "Script expects Premium Per Use Capacity."
    return
}

#Create Build Workspace
New-PowerBIWorkspace -Name $WSName

#Find Workspace and make sure it wasn't deleted (if it's old or you ran this script in the past)
$WSObj = Get-PowerBIWorkspace -Scope Organization -Filter "name eq '$($WSName)' and state ne 'Deleted'"

if($WSObj.Length -eq 0)
{
  Throw "$($WSName) workspace was not created."
}

#Update properties
Set-PowerBIWorkspace -Description "Workspace for Power BI Dataflow Polling" -Scope Organization -Id $WSObj.Id.Guid
Set-PowerBIWorkspace -CapacityId $Cap.Id.Guid -Scope Organization -Id $WSObj.Id.Guid 

#Assign service account admin rights to this workspace
Add-PowerBIWorkspaceUser -Id $WSObj[$WSObj.Length-1].Id.ToString() -AccessRight Admin -UserPrincipalName $SvcUser

Write-Host "Workspace ID: $($WSObj.Id.Guid)"

### Now Setup Azure DevOps
Write-Host -ForegroundColor Cyan "Step 2 of 6: Creating Azure DevOps project"

#Login using Azure CLI
$LogInfo = az login | ConvertFrom-Json

#Assumes organization name matches $LogInfo.name and url for Azure DevOps Service is https://dev.azure.com
$ProjectResult = az devops project create `
                --name $ProjectName `
                --description "Implementation of managing version control and testing of Gen1 Power BI dataflows" `
                --organization "$($AzDOHostURL)$($LogInfo.name)" `
                --source-control git `
                --visibility private `
                --open --only-show-errors

#Check result
if(!$ProjectResult) {
    Write-Error "Unable to Create Project"
    return
}

#Convert Result to JSON
$ProjectInfo = $ProjectResult | ConvertFrom-JSON

Write-Host -ForegroundColor Cyan "Step 3 of 6: Creating Repo in Azure DevOps project"
#Import Repo for kerski's GitHub
$RepoResult = az repos import create --git-source-url $RepoToCopy `
            --org "$($AzDOHostURL)$($LogInfo.name)" `
            --project $ProjectName `
            --repository $ProjectName --only-show-errors | ConvertFrom-Json

#Check Result
if(!$RepoResult) {
    Write-Error "Unable to Import Repository"
    return
}

# Step 4
Write-Host -ForegroundColor Cyan "Step 4 of 6: Creating PAT Token"

#Get the Azure Ad AccessToken
$ADToken = az account get-access-token | ConvertFrom-Json

<# Thanks to @autosysops for this article 
   which helped me generate PAT tokens
   more consistently.

   https://autosysops.com/blog/automatic-pat-renewal-for-azure-devops 
#>

#Create the authentication header for the DevOps API
$Headers = @{
    "Content-Type" = "application/json"
    Authorization = "Bearer $($ADToken.accessToken)"
}
      
#Retrieve all tokens
$Url = "https://vssps.dev.azure.com/$($LogInfo.name)/_apis/tokens/pats?api-version=7.1-preview.1"

# Set Valid To expiration
$Today = Get-Date
$FutureDate = $Today.AddDays(363).ToUniversalTime()
$FutureDateISO = $FutureDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

# Generate Guid
$PATGuid = New-Guid

# Setup payload to create token
$Body = @{
  displayName = "Polling Pipeline for backing up Power BI dataflows ($($PATGuid.Guid))"
  scope = "vso.code"
  validTo = "$($FutureDateISO)"
  allOrgs = "false"
}

$JsonBody = $Body | ConvertTo-Json 

# Issue creation request
$PATToken = Invoke-RestMethod -Uri $Url -Headers $Headers -Method POST -Body $JsonBody -Verbose

if(!$PATToken)
{
    Throw "Unable to generate PAT Token"
}

Write-Host -ForegroundColor Cyan "Step 5 of 6: Creating Pipeline in Azure DevOps project"

#Service connection required for non Azure Repos can be optionally provided in the command to run it non interatively
$PipelineResult = az pipelines create --name $PipelineName --repository-type "tfsgit" `
                --description "Polling Pipeline for backing up Power BI dataflows" `
                --org "$($AzDOHostURL)$($LogInfo.name)" `
                --project $ProjectName `
                --repository $ProjectName `
                --branch "main" `
                --yaml-path "/Scripts/CI/Dataflow-Polling-and-Backup-Schedule-Dev.yml" --skip-first-run --only-show-errors | ConvertFrom-Json

#Check Result
if(!$PipelineResult) {
    Write-Error "Unable to setup Pipeline"
    return
}


# Mapping - API_HOST - $AzDOHostURL
# Variable 'API_HOST' was defined in the Variables tab
# Assumes commericial environment
$VarResult = az pipelines variable create --name "API_HOST" --only-show-errors `
             --allow-override true --org "$($AzDOHostURL)$($LogInfo.name)" `
             --pipeline-id $PipelineResult.id `
             --project $ProjectName --value $AzDOHostURL

#Check Result
if(!$VarResult) {
    Write-Error "Unable to create pipeline variable API_HOST"
    return
}

# Mapping - ORGANIZATION_NAME - $LogInfo.name
# Variable 'ORGANIZATION_NAME' was defined in the Variables tab
$VarResult = az pipelines variable create --name "ORGANIZATION_NAME" --only-show-errors `
             --allow-override true --org "$($AzDOHostURL)$($LogInfo.name)" `
             --pipeline-id $PipelineResult.id `
             --project $ProjectName --value $LogInfo.name

#Check Result
if(!$VarResult) {
    Write-Error "Unable to create pipeline variable ORGANIZATION_NAME"
    return
}

# Variable 'PPU_USERNAME' was defined in the Variables tab
$VarResult = az pipelines variable create --name "PPU_USERNAME" --only-show-errors `
            --allow-override true --org "$($AzDOHostURL)$($LogInfo.name)" `
            --pipeline-name $PipelineName `
            --project $ProjectName --value $SvcUser

#Check Result
if(!$VarResult) {
    Write-Error "Unable to create pipeline variable PPU_USERNAME"
    return
}


# Variable 'PASSWORD' was defined in the Variables tab
$VarResult = az pipelines variable create --name "PPU_PASSWORD" --only-show-errors `
            --allow-override true --org "$($AzDOHostURL)$($LogInfo.name)" `
            --pipeline-name $PipelineName `
            --project $ProjectName --value $SvcPwd --secret $TRUE

#Check Result
if(!$VarResult) {
    Write-Error "Unable to create pipeline variable PPU_PASSWORD"
    return
}

# Variable 'PAT_TOKEN' was defined in the Variables tab
$VarResult = az pipelines variable create --name "PAT_TOKEN" --only-show-errors `
            --allow-override true --org "$($AzDOHostURL)$($LogInfo.name)" `
            --pipeline-name $PipelineName `
            --project $ProjectName --value $PATToken --secret $TRUE

#Check Result
if(!$VarResult) {
    Write-Error "Unable to create pipeline variable PAT_TOKEN"
    return
}

# Variable 'PBI_DEV_WS_ID' was defined in the Variables tab
$VarResult = az pipelines variable create --name "PBI_DEV_WS_ID" --only-show-errors `
            --allow-override true --org "$($AzDOHostURL)$($LogInfo.name)" `
            --pipeline-name $PipelineName `
            --project $ProjectName --value $WSObj.Id.Guid

#Check Result
if(!$VarResult) {
    Write-Error "Unable to create pipeline variable PBI_DEV_WS_ID"
    return
}

# Variable 'PROJECT_NAME' was defined in the Variables tab
$VarResult = az pipelines variable create --name "PROJECT_NAME" --only-show-errors `
            --allow-override true --org "$($AzDOHostURL)$($LogInfo.name)" `
            --pipeline-name $PipelineName `
            --project $ProjectName --value $ProjectName

#Check Result
if(!$VarResult) {
    Write-Error "Unable to create pipeline variable PROJECT_NAME"
    return
}

# Variable 'REPOSITORY_NAME' was defined in the Variables tab
$VarResult = az pipelines variable create --name "REPOSITORY_NAME" --only-show-errors `
            --allow-override true --org "$($AzDOHostURL)$($LogInfo.name)" `
            --pipeline-name $PipelineName `
            --project $ProjectName --value $RepoName

#Check Result
if(!$VarResult) {
    Write-Error "Unable to create pipeline variable REPOSITORY_NAME"
    return
}

# Variable 'TENANT_ID' was defined in the Variables tab
$VarResult = az pipelines variable create --name "TENANT_ID" --only-show-errors `
            --allow-override true --org "$($AzDOHostURL)$($LogInfo.name)" `
            --pipeline-name $PipelineName `
            --project $ProjectName --value $LogInfo.tenantId

#Check Result
if(!$VarResult) {
    Write-Error "Unable to create pipeline variable TENANT_ID"
    return
}

Write-Host -ForegroundColor Green "Azure DevOps Project $($ProjectName) created with pipeline $($PipelineName) at $($AzDOHostURL)$($LogInfo.name)"

#Clean up
#az devops project delete --id $ProjectInfo.id --organization "https://dev.azure.com/$($LogInfo.name)" --yes
#Invoke-PowerBIRestMethod -Url "groups/$($WSObj.Id.Guid)" -Method Delete