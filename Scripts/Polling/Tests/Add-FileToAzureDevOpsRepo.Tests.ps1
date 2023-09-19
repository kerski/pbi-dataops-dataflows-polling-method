# Note Pester 3 is preinstalled on many Windows 10/11 machines.
# Unistall Pester 3 with this script: https://gist.github.com/nohwnd/5c07fe62c861ee563f69c9ee1f7c9688
Describe 'Add-FileToAzureDevOpsRepo' {
    BeforeAll { 
        Import-Module ".\scripts\polling\Add-FileToAzureDevOpsRepo.psm1" -Force

        $ADOAPI = "https://dev.azure.com" 
        $OrganizationName =  "kerski" 
        $ProjectName =  "AzureDevOpsAPITest" 
        $RepositoryName  = "AzureDevOpsAPITest" 
        $AccessToken  = "zn6vcvvgmekvsd6uczbuzhxpuzka222rjg2hno6nhbhyf2qh4neq" 
        $BranchName  = "main" 
        $Path  = "Folder/$(Get-Date -Format "yyyyMMddHHmmss").txt" 
        $Content  = "hello world" 
        $CommitMessage  = "hello world "
    }

    #Check if File Exists
    It 'Module should exist' {
        $IsInstalled = Get-Command Add-FileToAzureDevOpsRepo
        $IsInstalled | Should -Not -BeNullOrEmpty
    }

    It 'Should throw an error because ADOAPI is empty' {
        {Add-FileToAzureDevOpsRepo -ADOAPI "" `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName "Does not exist" `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path `
        -Content $Content `
        -CommitMessage $CommitMessage} | Should Throw
    }

    It 'Should throw an error because Organization Name is empty' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName "" `
        -ProjectName $ProjectName `
        -RepositoryName "Does not exist" `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path `
        -Content $Content `
        -CommitMessage $CommitMessage} | Should Throw
    }    

    It 'Should throw an error because Project Name is empty' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName "" `
        -RepositoryName "Does not exist" `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path `
        -Content $Content `
        -CommitMessage $CommitMessage} | Should Throw
    }    

    It 'Should throw an error because Repository Name is empty' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName "" `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path `
        -Content $Content `
        -CommitMessage $CommitMessage} | Should Throw
    }    

    It 'Should throw an error because Access Token is empty' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken "" `
        -BranchName $BranchName `
        -Path $Path `
        -Content $Content `
        -CommitMessage $CommitMessage} | Should Throw
    }   

    It 'Should throw an error because Branch Name is empty' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName "" `
        -Path $Path `
        -Content $Content `
        -CommitMessage $CommitMessage} | Should Throw
    } 

    It 'Should throw an error because Path is empty' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path "" `
        -Content $Content `
        -CommitMessage $CommitMessage} | Should Throw
    }

    It 'Should throw an error because Content is empty' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path `
        -Content "" `
        -CommitMessage $CommitMessage} | Should Throw
    } 

    It 'Should throw an error because Commit Message is empty' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path `
        -Content $Content `
        -CommitMessage ""} | Should Throw
    }  
    
    It 'Should throw an error because Access Token is bad' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken "$($AccessToken)dfjadf" `
        -BranchName $BranchName `
        -Path $Path `
        -Content $Content `
        -CommitMessage ""} | Should Throw
    }     

    It 'Should throw an error because Repository does not exist' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName "Does not exist" `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path `
        -Content $Content `
        -CommitMessage $CommitMessage} | Should Throw
    }

    It 'Should throw an error because branch does not exist' {
        {Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName "badbranch" `
        -Path $Path `
        -Content $Content `
        -CommitMessage $CommitMessage} | Should Throw
    }

    It 'Should successfully complete adding a new file' {
        $Result = Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path `
        -Content $Content `
        -CommitMessage $CommitMessage

        $Result.commits | Should -Not -BeNullOrEmpty
    }

    It 'Should successfully complete updating existing file' {
        $Result = Add-FileToAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path `
        -Content "$($Content)xyz" `
        -CommitMessage $CommitMessage

        $Result.commits | Should -Not -BeNullOrEmpty
    }    

    #Clean up
    AfterAll {

    }

}