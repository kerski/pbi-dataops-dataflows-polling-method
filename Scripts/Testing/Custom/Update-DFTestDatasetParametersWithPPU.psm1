<#
    Author: John Kerski

    .SYNOPSIS
    This script updates the parameters of the Dataflow Test Dataset
    
    .DESCRIPTION
    This script updates the parameters of the Dataflow Test Dataset

    Dependencies: Write access to the workspace and dataset

    .PARAMETER WorkspaceId
    GUID representing workspace in the service

    .PARAMETER DatasetId
    GUID representing the dataset in the service

    .PARAMETER DataflowWorkspaceId
    GUID representing the dataflow's workspace in the service

    .PARAMETER DataflowId
    GUID representing the dataflow in the service

    .PARAMETER RunId
    GUID representing the test run for executing the test suite    

    .OUTPUTS
    Returns true if the update occurred, otherwise it will return false

    .EXAMPLE
    $UpdateResult = Update-DFTestDatasetParametersWithLocal -WorkspaceId $_WorkspaceObj.Id.Guid `
                                                -DatasetId $_DFTestObj.Id.Guid `
                                                -UserName $UserName `
                                                -Password $Password `
                                                -TenantId $TenantId `
                                                -DataflowWorkspaceId $_WorkspaceObj.Id.Guid `
                                                -DataflowId $_DFObjToTest.Id.Guid `
                                                -RunId $_RunID  
#>
Function Update-DFTestDatasetParametersWithPPU {
    [CmdletBinding()]
    Param(
              [Parameter(Position = 0, Mandatory = $true)][String]$WorkspaceId, 
              [Parameter(Position = 1, Mandatory = $true)][String]$DatasetId,
              [Parameter(Position = 2, Mandatory = $true)][String]$UserName,
              [Parameter(Position = 3, Mandatory = $true)][String]$Password,
              [Parameter(Position = 4, Mandatory = $true)][String]$DataflowWorkspaceId,
              [Parameter(Position = 5, Mandatory = $true)][String]$DataflowId,
              [Parameter(Position = 6, Mandatory = $false)][String]$RunId="Not Ready"                          
    )
    Process {
          Try {
              #Install Powershell Module if Needed
              if (Get-Module -ListAvailable -Name "MicrosoftPowerBIMgmt") {
                  Write-Host "MicrosoftPowerBIMgmt already installed"
              } else {
                   # Disable because build agent cannot find library, so we assume Start-CI.ps1 installs it.
                   Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -AllowClobber -Force
              }

              #Set Password as Secure String
              $Secret = $Password | ConvertTo-SecureString -AsPlainText -Force
              $Credentials = [System.Management.Automation.PSCredential]::new($UserName,$Secret)
              #Connect to Power BI
              $ConnectionStatus = Connect-PowerBIServiceAccount -Credential $Credentials
              #Setup Update Parameters Endpoint
              $UpdateUrl = "groups/$($WorkspaceId)/datasets/$($DatasetId)/Default.UpdateParameters"
              Write-Host "Updating Dataflow Testing Dataset: $($UpdateUrl)"
             
              # Set Parameter Updates
              $UpdateDetails = @{
               "updateDetails" = @(
                   @{"name" = "Workspace_ID"
                     "newValue" = "$($DataflowWorkspaceId)"},
                   @{"name" = "Dataflow_ID"
                     "newValue" = "$($DataflowId)"},
                   @{"name" = "Run_ID"
                     "newValue" = "$($RunId)"}
                 )
               }          
           
              # Convert to JSON
              $UpdateDetailsJson = $UpdateDetails | ConvertTo-Json
             
              #Issue Update
              $UpdateResult = Invoke-PowerBIRestMethod -Verbose -Url "$($UpdateUrl)" -Method Post -Body $UpdateDetailsJson
             
              return $true
          }Catch [System.Exception]{
            $ErrObj = ($_).Exception.InnerExceptionMessage
            Write-Host "##vso[task.logissue type=error]$($ErrObj)"
            exit 1
          }#End Try
 }#End Process
 }#End Function
               
 Export-ModuleMember -Function Update-DFTestDatasetParametersWithPPU