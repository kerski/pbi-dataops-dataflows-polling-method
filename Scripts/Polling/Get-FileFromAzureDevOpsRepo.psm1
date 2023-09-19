<#
.SYNOPSIS
Get a file to an Azure DevOps Repository's branch.

.PARAMETER ADOAPIHost
The host for the Azure DevOps Instance (e.g., https://dev.azure.com)

.PARAMETER OwnerName
The name of the GitHub repository owner.

.PARAMETER RepositoryName
The name of the GitHub repository.

.PARAMETER AccessToken
The access token to authenticate with the GitHub API.

.PARAMETER BranchName
The name of the branch to commit the file to.

.PARAMETER Path
The file path of the file to commit.

.EXAMPLE 
    Get-FileFromAzureDevOpsRepo -ADOAPIHost "https://dev.azure.com" `
        -OrganizationName "OrgName" `
        -ProjectName "ProjectX" `
        -RepositoryName "Adamantium" `
        -AccessToken "{Personal Access Token}" `
        -BranchName "development" `
        -Path "/Canada/testfile.txt" `
#>
function Get-FileFromAzureDevOpsRepo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ADOAPIHost,
        [Parameter(Mandatory = $true)]
        [string]$OrganizationName,
        [Parameter(Mandatory = $true)]
        [string]$ProjectName,
        [Parameter(Mandatory = $true)]
        [string]$RepositoryName,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$BranchName,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    # Setup URLs to issue to Azure DevOps
    $uriOrga = "$($ADOAPIHost)/$($OrganizationName)/" 
    $aDOAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AccessToken)")) }
    
    # Get Respository ID
    $uriRepoID = "$($uriOrga)/$($ProjectName)/_apis/git/repositories/?api-version=5.1"
    $repoInfo = Invoke-RestMethod -Uri $uriRepoID -Method Get -Headers $aDOAuthenicationHeader -ContentType "application/json"

    # Check Repository Information
    if($repoInfo) # exists
    {
       # Check if name matches
       $aDORepo = $repoInfo.value | Where-Object { $_.name -eq $RepositoryName }
       
       if(!$aDORepo)
       {
            throw "Unable to get repository id for the repository name supplied $($RepositoryName)"
       }#end check for repo id

       #Set Repo Id
       $aDORepoId = $aDORepo.id

       #Setup URIs to retrieve
       $uriGetItem = "$($uriOrga)$($ProjectName)/_apis/git/repositories/$($aDORepoId)/items?path=$($path)&api-version=5.1&versionDescriptor.version=$($BranchName)&download=true"

       Try{
            # Attempt to retrieve item
            $file = Invoke-RestMethod -Uri $uriGetItem -Method Get -Headers $aDOAuthenicationHeader -ContentType "application/json" 
            # Check for Branch ref
            if(!$file)
            {
                return $null
            }
            else #Add or Update
            {
                return $file
            }#end if
        }Catch [System.Exception]{
            # Retrieve Status Code
            $StatusCode = $_.Exception.Response.StatusCode
            # If not found
            if($StatusCode -eq [System.Net.HttpStatusCode]::NotFound){
                return $null
            } else{
                throw "Unable to get item at $($Path). Http Status Code: $($StatusCode)"
            }
       }# end try
    }
    else
    {
        throw "Unable to get repository information at $(uriRepoID) endpoint."
    }# end if
}
# Export the cmdlet from the module
Export-ModuleMember -Function Get-FileFromAzureDevOpsRepo