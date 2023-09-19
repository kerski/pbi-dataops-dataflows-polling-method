<#
.SYNOPSIS
Commits a file to an Azure DevOps Repository's branch.

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

.PARAMETER Content
The content to write to the file.

.PARAMETER CommitMessage
The commit message to use when committing the file.

.

.EXAMPLE 
    Add-FileToAzureDevOpsRepo -ADOAPIHost "https://dev.azure.com" `
        -OrganizationName "OrgName" `
        -ProjectName "ProjectX" `
        -RepositoryName "Adamantium" `
        -AccessToken "{Personal Access Token}" `
        -BranchName "development" `
        -Path "/Canada/testfile.txt" `
        -Content "This is a sample" `
        -CommitMessage "Updating test file..."
#>

function Add-FileToAzureDevOpsRepo {
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
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$CommitMessage
    )
    # Setup URLs to issue to Azure DevOps
    $uriOrga = "$($ADOAPIHost)/$($OrganizationName)/" 
    $aDOAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AccessToken)")) }
    
    $uriRepoID = "$($uriOrga)/$($ProjectName)/_apis/git/repositories/?api-version=5.1"

    # Get Respository ID
    $repoInfo = Invoke-RestMethod -Uri $uriRepoID -Method Get -Headers $aDOAuthenicationHeader -ContentType "application/json"

    if($repoInfo)
    {
       $aDORepo = $repoInfo.value | Where-Object { $_.name -eq $RepositoryName }
       
       if(!$aDORepo)
       {
            throw "Unable to get repository id for the repository name supplied $($RepositoryName)"
       }#end check for repo id

       #Set Repo Id
       $aDORepoId = $aDORepo.id

       #Setup URIs for commit
       $uriRef = "$($uriOrga)$($ProjectName)/_apis/git/repositories/$($aDORepoId)/refs?api-version=5.1"
       $uriPush = "$($uriOrga)$($ProjectName)/_apis/git/repositories/$($aDORepoId)/pushes?api-version=5.1"        
       #Template for push
       $addTemplate = @{
       "refUpdates" = @(
            @{
            "name" = "refs/heads/$($BranchName)"
            "oldObjectId" = "8b67126d2500e28c771f82c9ddc292679978197c"
            }
        )
        "commits" = @(
            @{
                "comment" = "$($CommitMessage)"
                "changes" = @(
                    @{
                        "changeType" = "add"
                        "item" = @{
                            "path" = "$($Path)"
                        }
                        "newContent" = @{
                            "content" = "$($Content)"
                            "contentType" = "rawtext"
                        }
                    }
                )
            }
        )}

        # Get Ref to get oldObjectId
        $refResult = Invoke-RestMethod -Uri $uriRef -Method Get -Headers $aDOAuthenicationHeader
        
        # Get Refs for the appropriate branch
        $branchRef = $refResult.value | Where-Object { $_.name -eq "refs/heads/$($BranchName)"}
        # Set variables for tracking requests
        $jSONBody = ""
        # Use to flag to store if the file is being added or edited
        $isAdd = $FALSE
           
        # Check for Branch ref
        if(!$branchRef)
        {
            throw "Unable to get referenced Id for repository: $($aDORepoId) and branch: $($branchName)."
        }
        else #Add or Update
        {
            $isAdd = $TRUE
            # Use template to create body for request
            $addJSON = $addTemplate
            # Assign reference Id and name to template JSON    
            $addJSON.refUpdates[0].oldObjectId = $branchRef.objectId
            #$addJSON.refUpdates[0].name = $branchName
            # Update template with the appropriate path and content
            $jSONBody = $addJSON | ConvertTo-Json -Depth 5
        }#end if

        # Push to appropriate repo and branch with add
        Try
        {
            $result = Invoke-RestMethod -Uri $uriPush -Method Post -Headers $aDOAuthenicationHeader -Body $jSONBody -ContentType "application/json"

            return $Result
        }Catch [System.Exception]{
            $errObj = ($_).ToString() | ConvertFrom-Json
            
            #Switch to edit instead of add
            if($errObj.message -like "*add operation already exists*")
            {
                $isAdd = $FALSE
            }
            else #not the error we were looking for
            {
                throw $errObj
            }
        }#End Try

        if($isAdd -eq $FALSE) # Issue edit request instead
        {
            $editJSON = $addJSON
            $editJSON.commits[0].changes[0].changeType = "edit"
            $jSONBody = $editJSON | ConvertTo-Json -Depth 5
            # Issue Edit Request
            $result = Invoke-RestMethod -Uri $uriPush -Method Post -Headers $aDOAuthenicationHeader -Body $jSONBody -ContentType "application/json"
            return $result
        }# end if Is Add check
    }
    else
    {
        throw "Unable to get repository information at $(uriRepoID) endpoint."
    }# end if
}

# Export the cmdlet from the module
Export-ModuleMember -Function Add-FileToAzureDevOpsRepo
