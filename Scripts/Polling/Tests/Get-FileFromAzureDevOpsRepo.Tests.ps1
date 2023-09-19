# Note Pester 3 is preinstalled on many Windows 10/11 machines.
# Unistall Pester 3 with this script: https://gist.github.com/nohwnd/5c07fe62c861ee563f69c9ee1f7c9688
Describe 'Get-FileFromAzureDevOpsRepo' {
    BeforeAll { 
        Import-Module ".\scripts\polling\Get-FileFromAzureDevOpsRepo.psm1" -Force

        $ADOAPI = "https://dev.azure.com" 
        $OrganizationName =  "kerski" 
        $ProjectName =  "AzureDevOpsAPITest" 
        $RepositoryName  = "AzureDevOpsAPITest" 
        $AccessToken  = "zn6vcvvgmekvsd6uczbuzhxpuzka222rjg2hno6nhbhyf2qh4neq" 
        $BranchName  = "main" 
        $Path  = "Folder/test.txt"
        $JsonPath = "Folder/dataflow-test.json"
    }

    #Check if File Exists
    It 'Module should exist' {
        $IsInstalled = Get-Command Get-FileFromAzureDevOpsRepo
        $IsInstalled | Should -Not -BeNullOrEmpty
    }

    It 'Should throw an error because ADOAPI is empty' {
        {Get-FileFromAzureDevOpsRepo -ADOAPI "" `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName "Does not exist" `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path} | Should Throw
    }

    It 'Should throw an error because Organization Name is empty' {
        {Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName "" `
        -ProjectName $ProjectName `
        -RepositoryName "Does not exist" `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path} | Should Throw
    }    

    It 'Should throw an error because Project Name is empty' {
        {Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName "" `
        -RepositoryName "Does not exist" `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path} | Should Throw
    }    

    It 'Should throw an error because Repository Name is empty' {
        {Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName "" `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path} | Should Throw
    }    

    It 'Should throw an error because Access Token is empty' {
        {Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken "" `
        -BranchName $BranchName `
        -Path $Path} | Should Throw
    }   

    It 'Should throw an error because Branch Name is empty' {
        {Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName "" `
        -Path $Path} | Should Throw
    } 

    It 'Should throw an error because Path is empty' {
        {Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path ""} | Should Throw
    }

    It 'Should retrieve a text file' {
        $Result = Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $Path

        $Result | Should -Be "helloworld"
    }

    It 'Should retrieve a dataflow (json) file' {
        $Result = Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path $JsonPath

        # Expect the dataflow json version to be "1.0"
        $Result.version | Should -Be "1.0"
    }    

    It 'Should return null when trying to retrieve a non-existent text file' {
        $Result = Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path "/Folder/doesnotexist.txt"

        $Result | Should -BeNullOrEmpty
    }


    It 'Should return null when retrieve a non-existent dataflow (json) file' {
        $Result = Get-FileFromAzureDevOpsRepo -ADOAPIHost $ADOAPI `
        -OrganizationName $OrganizationName `
        -ProjectName $ProjectName `
        -RepositoryName $RepositoryName `
        -AccessToken $AccessToken `
        -BranchName $BranchName `
        -Path "/Folder/doesnotexist.json"

        $Result | Should -BeNullOrEmpty
    }    

    #Clean up
    AfterAll {

    }

}