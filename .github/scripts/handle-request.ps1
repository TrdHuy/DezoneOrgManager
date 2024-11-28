# Input environment variables
$IssueNumber = $env:ISSUE_NUMBER
$IssueTitle = $env:ISSUE_TITLE
$IssueBody = $env:ISSUE_BODY
$IssueCreator = $env:ISSUE_CREATOR
$CreatorProfileUrl = $env:CREATOR_PROFILE_URL
$GithubRepo = $env:GITHUB_REPO
$GithubToken = $env:GITHUB_TOKEN
$PrivateRepoUrl = $env:PRIVATE_REPO_URL

# Step 1: Extract fields from issue body
Write-Host "Extracting issue details from issue #$IssueNumber..."
if ($IssueBody -match "Email Address:\s*(.+)") {
    $RequesterEmail = $matches[1]
    Write-Host "Extracted Requester Email: $RequesterEmail"
} else {
    Write-Error "Requester email not found in issue body!"
    Exit 1
}

# Email of the issue creator (optional, for logging)
Write-Host "Issue submitted by: $IssueCreator"
Write-Host "GitHub profile: $CreatorProfileUrl"

# Step 2: Clone the private repo
Write-Host "Cloning private repository..."
$PrivateRepoPath = "C:\private-repo"
if (Test-Path $PrivateRepoPath) {
    Remove-Item -Recurse -Force $PrivateRepoPath
}
git clone $PrivateRepoUrl $PrivateRepoPath
cd $PrivateRepoPath

# Step 3: Create a new branch and add changes
$BranchName = "request-build-permission-$IssueNumber"
Write-Host "Creating branch $BranchName..."
git checkout -b $BranchName

Write-Host "Creating request file..."
$RequestFilePath = "request_$IssueNumber.txt"
Set-Content -Path $RequestFilePath -Value @"
Request Build Permission
========================
- Issue Number: $IssueNumber
- Title: $IssueTitle
- Requester Email: $RequesterEmail
- Submitted by: $IssueCreator
- Profile URL: $CreatorProfileUrl
- Reason: $IssueBody
"@

Write-Host "Committing changes..."
git add .
git commit -m "Build Permission Request by $RequesterEmail for issue #$IssueNumber"
git push origin $BranchName

# Step 4: Create a pull request in private repo
Write-Host "Creating pull request..."
$PullRequestData = @{
    title = "Request Build Permission for Issue #$IssueNumber"
    head = $BranchName
    base = "main"
    body = "This pull request is auto-generated to request build permissions for issue #$IssueNumber.\n\n- **Requester Email**: $RequesterEmail\n- **Submitted by**: $IssueCreator ($CreatorProfileUrl)"
} | ConvertTo-Json -Depth 10

$PullRequestResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/private-org/private-repo-B/pulls" `
    -Headers @{Authorization = "Bearer $GithubToken"} `
    -Method POST `
    -Body $PullRequestData

if ($PullRequestResponse -ne $null) {
    Write-Host "Pull request created successfully: $($PullRequestResponse.html_url)"
} else {
    Write-Error "Failed to create pull request!"
    Exit 1
}

# Step 5: Notify user in original issue
Write-Host "Notifying user in original issue..."
$CommentBody = @{
    body = "Your request has been submitted as a pull request: $($PullRequestResponse.html_url). Please wait for it to be reviewed."
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "https://api.github.com/repos/$GithubRepo/issues/$IssueNumber/comments" `
    -Headers @{Authorization = "Bearer $GithubToken"} `
    -Method POST `
    -Body $CommentBody

Write-Host "Process completed successfully!"
