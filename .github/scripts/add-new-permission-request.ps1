. "$PSScriptRoot/utils/git-api-helper.ps1"
function Update-PermissionFile {
    param (
        [string]$BaseApiUrl,
        [string]$RepoOwner,
        [string]$RepoName,
        [string]$FilePath,
        [string]$BranchName,
        [string]$RequesterEmail,
        [string]$IssueCreator,
        [string]$SelectedPackage,
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

    $User = $JsonContent.users | Where-Object { $_.username -eq $IssueCreator }
    if (-not $User) {
        # Add new user
        $NewUser = @{
            username = $IssueCreator
            email    = $RequesterEmail
            packages = @{ $SelectedPackage = [guid]::NewGuid().ToString() }
        }
        $JsonContent.users += $NewUser
    }
    else {
        # Update existing user
        if (-not $User.packages.$SelectedPackage) {
            $User.packages.Add($SelectedPackage, [guid]::NewGuid().ToString())
        }
    }

    # Return updated JSON
    return @{
        UpdatedContent = $JsonContent | ConvertTo-Json -Depth 10
        Sha            = $FileContent.sha
    }
}

function Extract-IssueDetails {
    param (
        [string]$IssueBody
    )

    # Khởi tạo một hash table để lưu trữ kết quả
    $IssueDetails = @{}

    # Trích xuất Email Address
    if ($IssueBody -match "(?m)### Email Address\s*\n(.+?)\n") {
        $IssueDetails["RequesterEmail"] = $matches[1].Trim()
    }
    else {
        Write-Error "Requester email not found in issue body!"
        Exit 1
    }

    # Trích xuất Select Package
    if ($IssueBody -match "(?m)### Select Package\s*\n(.+?)\n") {
        $IssueDetails["SelectedPackage"] = $matches[1].Trim()
    }
    else {
        Write-Error "Selected package not found in issue body!"
        Exit 1
    }

    # Trích xuất Reason for Request
    if ($IssueBody -match "(?m)### Reason for Request\s*\n(.+?)\n") {
        $IssueDetails["Reason"] = $matches[1].Trim()
    }
    else {
        Write-Error "Reason for request not found in issue body!"
        Exit 1
    }

    # Trả về kết quả
    return $IssueDetails
}

$ISLOCAL = $env:ISLOCAL
if (-not $ISLOCAL) {
    $ISLOCAL = $true
}

$IssueNumber = $env:ISSUE_NUMBER
$AccessToken = $env:GITHUB_TOKEN
$OrgNameForValidation = $env:ORG_NAME_FOR_VALIDATION
$NameOfRepoContainingPermissionRequest = $env:NAME_OF_REPO_CONTAINING_PERMISSION_REQUEST
$RepoOwner = $env:REPO_OWNER
$RepoForSubmitRequest = $env:NAME_OF_REPO_TO_SUBMIT_REQUEST
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
    $RepoForSubmitRequest = $localXmlDoc.configuration.RepoForSubmitRequest
    $RepoOwner = $localXmlDoc.configuration.RepoOwner
    $BaseApiUrl = $localXmlDoc.configuration.BaseApiUrl

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

# Step 2: Kiểm tra membership
Write-Host "Validating membership for user $CreatorUsername..."
$IsMember = Validate-Membership -BaseApiUrl $BaseApiUrl `
    -OrgNameForValidation $OrgNameForValidation -CreatorUsername $CreatorUsername `
    -Headers $Headers
if (-not $IsMember) {
    Write-Host "User $CreatorUsername is not a member of $OrgNameForValidation."
    Close-Issue -BaseApiUrl $BaseApiUrl `
        -RepoOwner $RepoOwner -RepoName $NameOfRepoContainingPermissionRequest `
        -IssueNumber $IssueNumber `
        -CommentBody "Hi @$CreatorUsername, you need to be a member of the $OrgNameForValidation organization to have the required permissions. Please join the organization and re-open this issue once you have the necessary access." `
        -Headers $Headers
    Exit 0
}

# Step 3: Trích xuất thông tin từ issue body
Write-Host "Extracting issue details..."
$Details = Extract-IssueDetails -IssueBody $IssueBody
$RequesterEmail = $Details["RequesterEmail"]
$SelectedPackage = $Details["SelectedPackage"]
$Reason = $Details["Reason"]

# Step 4: Cập nhật file JSON
Write-Host "Updating permission file..."
$PermissionUpdate = Update-PermissionFile -BaseApiUrl $BaseApiUrl `
    -RepoOwner $RepoOwner -RepoName $RepoForSubmitRequest `
    -FilePath $PermissionFilePath -BranchName $BranchStorePermissionFile `
    -RequesterEmail $RequesterEmail -IssueCreator $CreatorUsername `
    -SelectedPackage $SelectedPackage -AccessToken $AccessToken

# Step 5: Tạo branch mới
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
$NewBranchName = "pbpr_i" + $IssueNumber + "___" + $CreatorUsername + "___" + $SelectedPackage
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

# Step 6: Commit changes to the new branch
$CommitMessage = "[$RequestUrl] Update <$SelectedPackage> permission for <$CreatorUsername>"
Write-Host "Committing changes to branch $NewBranchName..."
Update-GitHubContent -Owner $RepoOwner -Repo $RepoForSubmitRequest `
    -FilePath $PermissionFilePath -BranchName $NewBranchName `
    -Message  $CommitMessage -Content $PermissionUpdate.UpdatedContent `
    -Sha $PermissionUpdate.Sha -CommitterName "Automation" -CommitterEmail "trdtranduchuy@gmail.com" `
    -Token $AccessToken

# Step 7: Tạo pull request
$PullRequestBody = @"
### RequestId: 
    $IssueNumber
### User: 
    $CreatorUsername
### Email:
    $RequesterEmail
### Package: 
    $SelectedPackage
### Reason:
    $Reason
### [Detail]($RequestUrl) 
"@
Write-Host "Creating a pull request..."
$PullRequest = Create-PullRequest -RepoOwner $RepoOwner -Repo $RepoForSubmitRequest `
    -Title $CommitMessage -HeadBranch $NewBranchName -BaseBranch $BranchStorePermissionFile `
    -AccessToken $AccessToken -Body $PullRequestBody

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