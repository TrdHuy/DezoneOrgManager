# Input environment variables
$IssueNumber = $env:ISSUE_NUMBER
$IssueTitle = $env:ISSUE_TITLE
$IssueBody = $env:ISSUE_BODY
$IssueCreator = $env:ISSUE_CREATOR
$GithubRepo = $env:GITHUB_REPO
$GithubToken = $env:GITHUB_TOKEN
$PrivateRepoUrl = $env:PRIVATE_REPO_URL
$TargetOrg = "Dezone99"

# Step 1: Check if user belongs to the target organization
Write-Host "Checking if user $IssueCreator belongs to organization $TargetOrg..."
$OrgsApiUrl = "https://api.github.com/users/$IssueCreator/orgs"
$Headers = @{
    Authorization = "Bearer $GithubToken"
    Accept        = "application/vnd.github.v3+json"
}

try {
    # Call the GitHub API to get the user's organizations
    $OrgsResponse = Invoke-RestMethod -Uri $OrgsApiUrl -Headers $Headers -Method GET

    # Check if the user belongs to the target organization
    $IsInTargetOrg = $false
    foreach ($Org in $OrgsResponse) {
        if ($Org.login -eq $TargetOrg) {
            $IsInTargetOrg = $true
            break
        }
    }

    if (-not $IsInTargetOrg) {
        Write-Host "User $IssueCreator does NOT belong to the organization $TargetOrg. Closing issue."

        # Step 1.1: Comment on the issue
        $CommentBody = @{
            body = "You are not a member of the organization **$TargetOrg**. Unfortunately, you cannot request build permissions."
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri "https://api.github.com/repos/$GithubRepo/issues/$IssueNumber/comments" `
            -Headers @{Authorization = "Bearer $GithubToken"} `
            -Method POST `
            -Body $CommentBody

        # Step 1.2: Close the issue
        $CloseIssueBody = @{
            state = "closed"
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri "https://api.github.com/repos/$GithubRepo/issues/$IssueNumber" `
            -Headers @{Authorization = "Bearer $GithubToken"} `
            -Method PATCH `
            -Body $CloseIssueBody

        Write-Host "Issue #$IssueNumber has been closed."
        Exit 0
    } else {
        Write-Host "User $IssueCreator is a member of $TargetOrg. Continuing process."
    }
} catch {
    Write-Error "Failed to fetch organizations for user $IssueCreator: $_"
    Exit 1
}

# Step 2: Extract fields from issue body
Write-Host "Extracting issue details from issue #$IssueNumber..."
if ($IssueBody -match "Email Address:\s*(.+)") {
    $RequesterEmail = $matches[1]
    Write-Host "Extracted Requester Email: $RequesterEmail"
} else {
    Write-Error "Requester email not found in issue body!"
    Exit 1
}

# Continue with other processing steps (e.g., cloning repo, creating pull request, etc.)
Write-Host "Processing the request as user $IssueCreator is verified to belong to $TargetOrg..."
