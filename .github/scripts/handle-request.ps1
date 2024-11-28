# Input environment variables
$IssueNumber = $env:ISSUE_NUMBER
$IssueTitle = $env:ISSUE_TITLE
$IssueBody = $env:ISSUE_BODY
$GithubRepo = $env:GITHUB_REPO
$GithubToken = $env:GITHUB_TOKEN
$PrivateRepoUrl = $env:PRIVATE_REPO_URL

# Step 1: Extract fields from issue body
Write-Host "Extracting issue details from issue #$IssueNumber..."
if ($IssueBody -match "Email Address:\s*(.+)") {
    $Email = $matches[1]
    Write-Host "Extracted Email: $Email"
} else {
    Write-Error "Email not found in issue body!"
    Exit 1
}

if ($IssueBody -match "Select Package:\s*(.+)") {
    $Package = $matches[1]
    Write-Host "Extracted Package: $Package"
} else {
    Write-Error "Package not found in issue body!"
    Exit 1
}

if ($IssueBody -match "Reason for Request:\s*(.+)") {
    $Reason = $matches[1]
    Write-Host "Extracted Reason: $Reason"
} else {
    Write-Error "Reason not found in issue body!"
    Exit 1
}

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
- Email: $Email
- Package: $Package
- Reason: $Reason
"@

Write-Host "Committing changes..."
git add .
git commit -m "Request Build Permission for $Package by $Email"
git push origin $BranchName

# Step 4: Create a pull request in private repo
Write-Host "Creating pull request..."
$PullRequestData = @{
    title = "Request Build Permission for $Package"
    head = $BranchName
    base = "main"
    body = "This pull request is auto-generated to request build permissions for the following:\n\n- **Package**: $Package\n- **Requested by**: $Email\n- **Reason**: $Reason\n\nLinked Issue: https://github.com/$GithubRepo/issues/$IssueNumber"
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
