# Load Helper Functions
. "$PSScriptRoot/utils/git-api-helper.ps1"
function Update-PermissionFileToRemoveUser {
     param (
          [string]$BaseApiUrl,
          [string]$RepoOwner,
          [string]$RepoName,
          [string]$FilePath,
          [string]$BranchName,
          [string]$GitHubUsername,
          [string]$AccessToken
     )
 
     $FileApiUrl = "$BaseApiUrl/repos/$RepoOwner/$RepoName/contents/" + $FilePath + "?ref=$BranchName"
 
     # Fetch file content
     $Headers = @{
          Accept        = "application/vnd.github.v3+json"
          Authorization = "Bearer $AccessToken"
     }
     $FileContent = Invoke-RestMethod -Uri $FileApiUrl -Headers $Headers -Method GET
     if (-not $FileContent) {
          Write-Error "Failed to fetch $FilePath from branch $BranchName."
          throw
     }
 
     # Decode and update JSON
     $DecodedContent = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($FileContent.content))
     $JsonContent = $DecodedContent | ConvertFrom-Json
 
     # Remove user
     $User = $JsonContent.users | Where-Object { $_.username -eq $GitHubUsername }
     if ($User) {
          $JsonContent.users = $JsonContent.users | Where-Object { $_.username -ne $GitHubUsername }
          Write-Host "Removed user $GitHubUsername from permissions."
     }
     else {
          Write-Warning "User $GitHubUsername not found in permissions."
          return $null
     }
 
     # Return updated JSON
     return @{
          UpdatedContent = $JsonContent | ConvertTo-Json -Depth 10
          Sha            = $FileContent.sha
     }
}
 
function Extract-RemovePermissionDetails {
     param (
          [string]$IssueBody
     )
 
     # Khởi tạo một hash table để lưu trữ kết quả
     $IssueDetails = @{}
 
     # Trích xuất GitHub Username
     if ($IssueBody -match "(?m)### GitHub Username\s*\n(.+?)\n") {
          $IssueDetails["GitHubUsername"] = $matches[1].Trim()
     }
     else {
          Write-Error "GitHub Username not found in issue body!"
          Exit 1
     }
 
     # Trích xuất Reason for Removal
     if ($IssueBody -match "(?m)### Reason for Removal\s*\r?\n(.+?)($|\r?\n)") {
          $IssueDetails["ReasonForRemoval"] = $matches[1].Trim()
     }
     else {
          Write-Error "Reason for Removal not found in issue body!"
     }
 
     # Trả về kết quả
     return $IssueDetails
}
 
$IssueNumber = $env:ISSUE_NUMBER
$AccessToken = $env:GITHUB_TOKEN
$OrgNameForValidation = $env:ORG_NAME_FOR_VALIDATION
$NameOfRepoContainingPermissionRequest = $env:NAME_OF_REPO_CONTAINING_PERMISSION_REQUEST
$RepoForSubmitRequest = $env:NAME_OF_REPO_TO_SUBMIT_REQUEST
$RepoOwner = $env:REPO_OWNER
$BaseApiUrl = "https://api.github.com"
if ($ISLOCAL -eq $true) {
     Write-Host "Assign local variable"

     $localXmlString = Get-Content -Raw -Path "local.config"
   
     # Tạo đối tượng XmlDocument và load chuỗi XML vào nó
     $localXmlDoc = New-Object System.Xml.XmlDocument
     $localXmlDoc.PreserveWhitespace = $true
     $localXmlDoc.LoadXml($localXmlString)

     $AccessToken = $localXmlDoc.configuration.AccessToken
     $IssueNumber = $localXmlDoc.configuration.IssueNumber
     $OrgNameForValidation = $localXmlDoc.configuration.OrgNameForValidation
     $NameOfRepoContainingPermissionRequest = $localXmlDoc.configuration.NameOfRepoContainingPermissionRequest
     $RepoOwner = $localXmlDoc.configuration.RepoOwner
     $BaseApiUrl = $localXmlDoc.configuration.BaseApiUrl
     $RepoForSubmitRequest = $localXmlDoc.configuration.RepoForSubmitRequest

}

# Headers
$Headers = @{
     Accept        = "application/vnd.github.v3+json"
     Authorization = "Bearer $AccessToken"
}

# Step 1: Lấy thông tin issue
Write-Host "Fetching issue details..."
$IssueResponse = Get-IssueDetails -BaseApiUrl $BaseApiUrl `
     -RepoOwner $RepoOwner -RepoName $NameOfRepoContainingPermissionRequest `
     -IssueNumber $IssueNumber -Headers $Headers
$CreatorUsername = $IssueResponse.user.login
$IssueBody = $IssueResponse.body
$RequestUrl = $IssueResponse.html_url
# Kiểm tra trạng thái của issue
if ($IssueResponse.state -eq "closed") {
     Write-Host "Issue #$IssueNumber is already closed. Exiting script."
     Exit 0
}

# Step 2: Trích xuất thông tin từ issue body
Write-Host "Extracting remove permission details..."
$Details = Extract-RemovePermissionDetails -IssueBody $IssueBody
$GitHubUsernameToRemove = $Details["GitHubUsername"]
$ReasonForRemoval = $Details["ReasonForRemoval"]

# Step 3: Cập nhật file JSON để xóa quyền
Write-Host "Updating permission file to remove user $GitHubUsernameToRemove..."
$PermissionUpdate = Update-PermissionFileToRemoveUser -BaseApiUrl $BaseApiUrl `
     -RepoOwner $RepoOwner -RepoName $RepoForSubmitRequest `
     -FilePath $PermissionFilePath -BranchName $BranchStorePermissionFile `
     -GitHubUsername $GitHubUsernameToRemove -AccessToken $AccessToken

if (-not $PermissionUpdate) {
     Write-Error "Failed to update permission file to remove user $GitHubUsernameToRemove."
     Close-Issue -BaseApiUrl $BaseApiUrl `
          -RepoOwner $RepoOwner -RepoName $NameOfRepoContainingPermissionRequest `
          -IssueNumber $IssueNumber `
          -CommentBody "Hi @$CreatorUsername, an error occurred while processing your request to remove permissions for @$GitHubUsernameToRemove. Please try again later." `
          -Headers $Headers
     Exit 1
}

# Step 4: Tạo branch mới
Write-Host "Creating a new branch for the changes..."
$branchInfo = Get-GithubBranchInfo -Owner $RepoOwner `
     -Repo $RepoForSubmitRequest -Token $AccessToken -BranchName $BranchStorePermissionFile
if (-not $branchInfo) {
     Write-Error "Failed to get branch info. Cannot proceed."
     Close-Issue -BaseApiUrl $BaseApiUrl `
          -RepoOwner $RepoOwner -RepoName $NameOfRepoContainingPermissionRequest `
          -IssueNumber $IssueNumber `
          -CommentBody "Hi @$CreatorUsername, an error occurred while processing your request. Please try again later." `
          -Headers $Headers
     Exit 1
}
$targetSha = $branchInfo.commit.sha
$NewBranchName = "pbpr_remove_permissions_" + $IssueNumber + "_$GitHubUsernameToRemove"
$tmp = Create-GitHubRef -Owner $RepoOwner -Repo $RepoForSubmitRequest `
     -Token $AccessToken -BranchName $NewBranchName -Sha $targetSha
if (-not $tmp) {
     Write-Error "Failed to create new branch. Cannot proceed."
     Close-Issue -BaseApiUrl $BaseApiUrl `
          -RepoOwner $RepoOwner -RepoName $NameOfRepoContainingPermissionRequest `
          -IssueNumber $IssueNumber `
          -CommentBody "Hi @$CreatorUsername, an error occurred while creating a new branch. Please try again later." `
          -Headers $Headers
     Exit 1
}

# Step 5: Commit changes to the new branch
$CommitMessage = "[$RequestUrl] Remove all build permissions for <$GitHubUsernameToRemove>"
Write-Host "Committing changes to branch $NewBranchName..."
Update-GitHubContent -Owner $RepoOwner -Repo $RepoForSubmitRequest `
     -FilePath $PermissionFilePath -BranchName $NewBranchName `
     -Message $CommitMessage -Content $PermissionUpdate.UpdatedContent `
     -Sha $PermissionUpdate.Sha -CommitterName "Automation" -CommitterEmail "trdtranduchuy@gmail.com" `
     -Token $AccessToken

# Step 6: Tạo pull request
$PullRequestBody = @"
### RequestId: 
    $IssueNumber
### GitHubUsernameToRemove: 
    $GitHubUsernameToRemove
### Reason:
    $Reason
### [Detail]($RequestUrl)
"@

Write-Host "Creating a pull request..."
$PullRequest = Create-PullRequest -RepoOwner $RepoOwner -Repo $RepoForSubmitRequest `
     -Title $CommitMessage -HeadBranch $NewBranchName -BaseBranch $BranchStorePermissionFile `
     -AccessToken $AccessToken -Body $PullRequestBody

Write-Host "Process completed successfully!"

if ($PullRequest) {
     Write-Host "Pull request created successfully: $($PullRequest.html_url)"
     
     # Step 8: Comment lên issue
     $CommentText = "Your request has been processed successfully and is awaiting approval![$($PullRequest.html_url)]($($PullRequest.html_url)).\n\nThe request is now under review."
     Comment-OnIssue -BaseApiUrl $BaseApiUrl `
          -RepoOwner $RepoOwner -RepoName $NameOfRepoContainingPermissionRequest `
          -IssueNumber $IssueNumber -CommentText $CommentText -Headers $Headers
}
else {
     Write-Error "Failed to create pull request."
     Exit 1
}