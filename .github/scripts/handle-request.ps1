$IssueNumber = $env:ISSUE_NUMBER
$IssueTitle = $env:ISSUE_TITLE
$IssueBody = $env:ISSUE_BODY
$IssueCreator = $env:ISSUE_CREATOR
$AccessToken = $env:GITHUB_TOKEN

$OrgName = "Dezone99"
$RepoName = "DezoneOrgManager"  # Thay bằng tên repo của bạn

# API endpoints
$IssueApiUrl = "https://api.github.com/repos/TrdHuy/$RepoName/issues/$IssueNumber"
$OrgMembersApiUrl = "https://api.github.com/orgs/$OrgName/members"

# Headers
$Headers = @{
    Accept        = "application/vnd.github.v3+json"
    Authorization = "Bearer $AccessToken"
}

try {
    # 1. Lấy thông tin issue
    $IssueResponse = Invoke-RestMethod -Uri $IssueApiUrl -Headers $Headers -Method GET
    $CreatorUsername = $IssueResponse.user.login  # Lấy username của người tạo issue
    $IssueBody = $IssueResponse.body

    # 2. Lấy danh sách tất cả các thành viên của tổ chức
    $MembersResponse = Invoke-RestMethod -Uri $OrgMembersApiUrl -Headers $Headers -Method GET
    $IsMember = $MembersResponse | Where-Object { $_.login -eq $CreatorUsername }

    if (-not $IsMember) {
        Write-Host "User $CreatorUsername is not a member of $OrgName."

        # 3. Gửi comment yêu cầu tham gia tổ chức
        $CommentApiUrl = "$IssueApiUrl/comments"
        $CommentBody = @{
            body = "Hi @$CreatorUsername, you need to be a member of the $OrgName organization to have the required permissions. Please join the organization and re-open this issue once you have the necessary access."
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri $CommentApiUrl -Headers $Headers -Method POST -Body $CommentBody

        # 4. Đóng issue
        $CloseIssueBody = @{
            state = "closed"
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri $IssueApiUrl -Headers $Headers -Method PATCH -Body $CloseIssueBody

        Write-Host "Issue #$IssueNumber has been closed."
    }
    else {
        Write-Host "User $CreatorUsername is a member of $OrgName. No further action required."
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)"
}


# Step 2: Extract fields from issue body
Write-Host "Extracting issue details from issue #$IssueNumber..."
# Trích xuất Email Address
if ($IssueBody -match "(?m)### Email Address\s*\n(.+?)\n") {
    $RequesterEmail = $matches[1].Trim()
    Write-Host "Extracted Requester Email: $RequesterEmail"
} else {
    Write-Error "Requester email not found in issue body!"
    Exit 1
}

# Trích xuất Select Package
if ($IssueBody -match "(?m)### Select Package\s*\n(.+?)\n") {
    $SelectedPackage = $matches[1].Trim()
    Write-Host "Extracted Selected Package: $SelectedPackage"
} else {
    Write-Error "Selected package not found in issue body!"
    Exit 1
}

# Trích xuất Reason for Request
if ($IssueBody -match "(?m)### Reason for Request\s*\n(.+?)\n") {
    $Reason = $matches[1].Trim()
    Write-Host "Extracted Reason for Request: $Reason"
} else {
    Write-Error "Reason for request not found in issue body!"
    Exit 1
}
