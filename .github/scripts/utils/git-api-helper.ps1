function Create-PullRequest {
     param (
          [string]$RepoOwner,
          [string]$Repo,
          [string]$Title,
          [string]$HeadBranch,
          [string]$BaseBranch,
          [string]$AccessToken,
          [string]$Body
     )
 
     $PullRequest = New-GitHubPullRequest -Owner $RepoOwner -Repo $Repo -Title $Title `
          -HeadBranch $HeadBranch -BaseBranch $BaseBranch -Token $AccessToken -Body $Body
 
     if ($PullRequest) {
          Write-Host "Pull request created successfully: $($PullRequest.html_url)"
     }
     else {
          Write-Error "Failed to create pull request."
          throw
     }
     return $PullRequest
}
function Comment-OnIssue {
     param (
          [string]$BaseApiUrl,
          [string]$RepoOwner,
          [string]$RepoName,
          [string]$IssueNumber,
          [string]$CommentText,
          [hashtable]$Headers
     )
 
     $CommentApiUrl = "$BaseApiUrl/repos/$RepoOwner/$RepoName/issues/$IssueNumber/comments"
 
     try {
          # Tạo nội dung comment
          $CommentBody = @{
               body = $CommentText
          } | ConvertTo-Json -Depth 10
 
          # Gửi request POST để tạo comment
          Write-Host "Posting comment to issue #$IssueNumber..."
          $Response = Invoke-RestMethod -Uri $CommentApiUrl -Headers $Headers -Method POST -Body $CommentBody
          Write-Host "Comment posted successfully."
          return $Response
     }
     catch {
          Write-Error "Failed to post comment to issue #$IssueNumber : $_"
          return $null
     }
}

function Validate-Membership {
     param (
          [string]$BaseApiUrl,
          [string]$OrgNameForValidation,
          [string]$CreatorUsername,
          [hashtable]$Headers
     )
 
     $OrgMembersApiUrl = "$BaseApiUrl/orgs/$OrgNameForValidation/members"
 
     try {
          $MembersResponse = Invoke-RestMethod -Uri $OrgMembersApiUrl -Headers $Headers -Method GET
          $IsMember = $MembersResponse | Where-Object { $_.login -eq $CreatorUsername }
          return $IsMember
     }
     catch {
          Write-Error "Failed to validate membership from $OrgMembersApiUrl : $_"
          throw
     }
}

function Close-Issue {
     param (
          [string]$BaseApiUrl,
          [string]$RepoOwner,
          [string]$RepoName,
          [string]$IssueNumber,
          [string]$CommentBody,
          [hashtable]$Headers
     )
 
     $IssueApiUrl = "$BaseApiUrl/repos/$RepoOwner/$RepoName/issues/$IssueNumber"
     $CommentApiUrl = "$IssueApiUrl/comments"
 
     try {
          # Post comment
          $CommentData = @{
               body = $CommentBody
          } | ConvertTo-Json -Depth 10
          Invoke-RestMethod -Uri $CommentApiUrl -Headers $Headers -Method POST -Body $CommentData
 
          # Close issue
          $CloseIssueBody = @{
               state = "closed"
          } | ConvertTo-Json -Depth 10
          Invoke-RestMethod -Uri $IssueApiUrl -Headers $Headers -Method PATCH -Body $CloseIssueBody
 
          Write-Host "Issue #$IssueNumber closed and comment posted."
     }
     catch {
          Write-Error "Failed to close issue from $IssueApiUrl : $_"
          throw
     }
}
 
 
function Get-IssueDetails {
     param (
          [string]$BaseApiUrl,
          [string]$RepoOwner,
          [string]$RepoName,
          [string]$IssueNumber,
          [hashtable]$Headers
     )
 
     $IssueApiUrl = "$BaseApiUrl/repos/$RepoOwner/$RepoName/issues/$IssueNumber"
 
     try {
          $IssueResponse = Invoke-RestMethod -Uri $IssueApiUrl -Headers $Headers -Method GET
          return $IssueResponse
     }
     catch {
          Write-Error "Failed to fetch issue details from $IssueApiUrl : $_"
          throw
     }
}
 
function Get-GitHubContentFromPath {
     param (
          [string]$Owner,
          [string]$Repo,
          [string]$FilePath,
          [string]$BranchName,
          [string]$Token
     )
  
     # Đường dẫn API và header
     $uri = "https://api.github.com/repos/$Owner/$Repo/contents/$FilePath"
     $headers = @{
          Authorization          = "Bearer $Token"
          Accept                 = "application/vnd.github.v3+json"
          'X-GitHub-Api-Version' = '2022-11-28'
     }
  
     # Thêm tham số ref vào URI nếu cung cấp BranchName
     if (-not [string]::IsNullOrWhiteSpace($BranchName)) {
          $uri += "?ref=$BranchName"
     }
  
     try {
          # Thực hiện yêu cầu GET
          $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
          return $response
     }
     catch {
          Write-Error "Failed to fetch GitHub content: $_"
          return $null
     }
}
function Get-GithubBranchInfo {
     param (
          [string]$Owner,
          [string]$Repo,
          [string]$Token,
          [string]$BranchName
     )
 
     $uri = "https://api.github.com/repos/$Owner/$Repo/branches/$BranchName"
     $headers = @{
          Authorization          = "Bearer $Token"
          'X-GitHub-Api-Version' = '2022-11-28'
     }
 
     $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers  -ContentType 'application/json'
 
     # Trả về kết quả phản hồi
     return $response
}
function Create-GitHubRef {
     param (
          [string]$Owner,
          [string]$Repo,
          [string]$Token,
          [string]$Sha,
          [string]$BranchName
     )
 
     $uri = "https://api.github.com/repos/$Owner/$Repo/git/refs"
     $headers = @{
          Authorization          = "Bearer $Token"
          'X-GitHub-Api-Version' = '2022-11-28'
     }
 
     $body = @{
          ref = "refs/heads/$BranchName"
          sha = $Sha
     } | ConvertTo-Json
 
     $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType 'application/json'
 
     # Trả về kết quả phản hồi
     return $response
}

function Update-GitHubContent {
     param (
          [string]$Owner,
          [string]$Repo,
          [string]$FilePath,
          [string]$BranchName,
          [string]$Sha,
          [string]$Message,
          [string]$CommitterName,
          [string]$CommitterEmail,
          [string]$Content,
          [string]$Token
     )
 
     $uri = "https://api.github.com/repos/$Owner/$Repo/contents/$FilePath"
     $headers = @{
          Authorization          = "Bearer $Token"
          'X-GitHub-Api-Version' = '2022-11-28'
          Accept                 = 'application/vnd.github.v3+json'
     }
 
     $body = @{
          message   = $Message
          content   = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Content))
          branch    = $BranchName
          sha       = $Sha
          committer = @{
               name  = $CommitterName
               email = $CommitterEmail
          }
     } | ConvertTo-Json
 
     $response = Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $body -ContentType 'application/json'
     return $response
}

function New-GitHubPullRequest {
     param (
          [string]$Owner,
          [string]$Repo,
          [string]$Title,
          [string]$HeadBranch,
          [string]$BaseBranch,
          [string]$Token,
          [string]$Body
     )
 
     # Đường dẫn API
     $uri = "https://api.github.com/repos/$Owner/$Repo/pulls"
     $headers = @{
          Authorization          = "Bearer $Token"
          Accept                 = "application/vnd.github.v3+json"
          'X-GitHub-Api-Version' = '2022-11-28'
     }
 
     # Thân yêu cầu
     $body = @{
          title = $Title
          head  = $HeadBranch
          base  = $BaseBranch
          body  = $Body
     } | ConvertTo-Json
 
     # Thực hiện yêu cầu POST
     try {
          $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType 'application/json'
          return $response
     }
     catch {
          Write-Error "Failed to create pull request: $_"
          return $null
     }
}
