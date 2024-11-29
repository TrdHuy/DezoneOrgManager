$ISLOCAL = $env:ISLOCAL
if (-not $ISLOCAL) {
    $ISLOCAL = $true
}

# Load required environment variables
$IssueTitle = $env:ISSUE_TITLE
$ScriptRoot = $PSScriptRoot  # Lấy thư mục chứa script hiện tại

if ($ISLOCAL -eq $true) {
    Write-Host "Assign local variable"

    $localXmlString = Get-Content -Raw -Path "local.config"
   
    # Tạo đối tượng XmlDocument và load chuỗi XML vào nó
    $localXmlDoc = New-Object System.Xml.XmlDocument
    $localXmlDoc.PreserveWhitespace = $true
    $localXmlDoc.LoadXml($localXmlString)

    $IssueTitle = $localXmlDoc.configuration.IssueTitle
}

# Kiểm tra tiêu đề issue
Write-Host "Processing issue with title: $IssueTitle"

if ($IssueTitle -eq "[PBPR] Package Build Permission") {
    Write-Host "Detected 'Add New Permission Request'. Calling add-new-permission-request.ps1..."
    & "$ScriptRoot/add-new-permission-request.ps1"
}
elseif ($IssueTitle -eq "[PBPR] Remove Permission") {
    Write-Host "Detected 'Remove Permission Request'. Calling remove-permission.ps1..."
    & "$ScriptRoot/remove-permission.ps1"
}
else {
    Write-Error "Unrecognized issue title format: $IssueTitle"
    Exit 1
}

Write-Host "Issue handled successfully."
