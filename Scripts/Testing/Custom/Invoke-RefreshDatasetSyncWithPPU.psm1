<#
    .SYNOPSIS
    This script runs a synchronous refresh of a dataset against the WorkspaceId identified.

    .DESCRIPTION
    This script runs a synchronous refresh of a dataset against the WorkspaceId identified.
    Dependencies: Premium Per User license purchased and assigned to UserName and UserName has admin right to workspace.

    .PARAMETER WorkspaceId
    GUID representing workspace in the service

    .PARAMETER DatasetId
    GUID represnting the dataset in the service

    .PARAMETER UserName
    Service Account's UserName

    .PARAMETER Password
    Service Account's Password

    .PARAMETER Tenant ID
    App Service Principal's Tenant ID

    .PARAMETER IsAsync
    True if you want the refresh to be asynchronous.  False by default (which indicates synchronous)

    .OUTPUTS
    Refresh json as defined is MS Docs: https://learn.microsoft.com/en-us/rest/api/power-bi/datasets/get-refresh-history-in-group#refresh

    .EXAMPLE
   $RefreshResult = Invoke-RefreshDatasetSyncWithPPU -WorkspaceId $BuildGroupId `
                  -DatasetId $DatasetId `
                  -UserName $UserName `
                  -Password $Password
#>
Function Invoke-RefreshDatasetSyncWithPPU {
    [CmdletBinding()]
    Param(
              [Parameter(Position = 0, Mandatory = $true)][String]$WorkspaceId, 
              [Parameter(Position = 1, Mandatory = $true)][String]$DatasetId,
              [Parameter(Position = 2, Mandatory = $true)][String]$UserName,
              [Parameter(Position = 3, Mandatory = $true)][String]$Password,
              [Parameter(Position = 4, Mandatory = $false)][bool]$IsAsync = $false
    )
    Process {
          Try {
              #Install Powershell Module if Needed
              if (Get-Module -ListAvailable -Name "MicrosoftPowerBIMgmt") {
                  Write-Host "MicrosoftPowerBIMgmt already installed"
              } else {
                   # Disable because build agent cannot find library, so we assume Start-CI.ps1 installs it.
                   #Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -AllowClobber -Force
              }
              #Set Password as Secure String
              $Secret = $Password | ConvertTo-SecureString -AsPlainText -Force
              $Credentials = [System.Management.Automation.PSCredential]::new($UserName,$Secret)
              #Connect to Power BI
              $ConnectionStatus = Connect-PowerBIServiceAccount -Credential $Credentials
              #Setup Refresh Endpoint
              $RefreshUrl = "groups/$($WorkspaceId)/datasets/$($DatasetId)/refreshes"
              Write-Host "Refreshing via URL: $($RefreshUrl)"
              #Issue Data Refresh
              $ResultResult = Invoke-PowerBIRestMethod -Verbose -Url "$($RefreshUrl)" -Method Post -Body "{ `"type`": `"full`",`"commitMode`": `"transactional`",`"notifyOption`": `"NoNotification`"}"
              #Check for Refresh to Complete
              Start-Sleep -Seconds 10 #wait ten seconds before checking refresh first time
              $CheckRefresh = 1
 
              if($IsAsync) # Short circuit to run once if async
              {
                $CheckRefresh = 0
                return "Unknown"
              }
             
              Do
              {
               $RefreshResult = Invoke-PowerBIRestMethod -Url "$($RefreshUrl)?`$top=1" -Method Get | ConvertFrom-JSON
               #Check date timestamp and verify no issue with top 1 being old
               $TimeSinceRequest = New-Timespan -Start $RefreshResult.value[0].startTime -End (Get-Date)
               if($TimeSinceRequest.Minutes > 30)
               {
                  $CheckRefresh = 1
               }#Check status.  Not Unknown means in progress
               elseif($RefreshResult.value[0].status -eq "Completed")
               {
                  $CheckRefresh = 0
                  Write-Host "Refreshed Completed"
                  return "Completed"
               }
               elseif($RefreshResult.value[0].status -eq "Failed")
               {
                  $CheckRefresh = 0
                  Write-Host "Refreshed Failed"
                  return "Failed"
               }
               elseif($RefreshResult.value[0].status -ne "Unknown")
               {
                  $CheckRefresh = 0
                  Write-Host "Refresh Status Unknown"
                  return "Unknown"
               }
               else #In Progress check, PBI uses Unknown for status
               {
                  $CheckRefresh = 1
                  Write-Host "Refresh Still In Progress"
                  Start-Sleep -Seconds 10 #sleep wait seconds before running again
               }
              } While ($CheckRefresh -eq 1)  
             
              return $RefreshResult.value[0]    
          }Catch [System.Exception]{
            $ErrObj = ($_).Exception.InnerExceptionMessage
            Write-Host "##vso[task.logissue type=error]$($ErrObj)"
            exit 1
          }#End Try
 }#End Process
 }#End Function
               
 Export-ModuleMember -Function Invoke-RefreshDatasetSyncWithPPU