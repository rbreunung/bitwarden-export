# I implement this script with latest Powershell available an do not intend to test older ones. It may or may be not working for Powershell 5.
#Requires -Version 7.0

# https://learn.microsoft.com/de-de/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.4
# ensure the output is UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function New-ExportFolder {
    $exportFolderName = "export-$(Get-Date -Format "yyyy-MM-dd-HH-mm-ss")"
    $exportDirectory = Join-Path -Path (Get-Location) -ChildPath $exportFolderName
    New-Item -Path $exportDirectory -ItemType Directory
}

# check bitwarden unlocked
$bitwardenStatus = Invoke-Expression "bw status"  | ConvertFrom-Json -Depth 1 | Select-Object -ExpandProperty status
if ( -not ($bitwardenStatus -eq "unlocked") ) {
    Write-Error "Bitwarden is not unlocked! Please unlock your Bitwarden CLI."
    Pause
    return -1
}

# create the export directory
$exportDirectory = New-ExportFolder

# Read data from Bitwarden
$exportFile = Join-Path -Path $exportDirectory -ChildPath "export-private.json"
$null = Invoke-Expression -Command "bw export --format json --output `"$exportFile`" "
$bitwardenOrganizations = Invoke-Expression -Command "bw list organizations" | ConvertFrom-Json -Depth 2
$bitwardenContent = Get-Content -Path $exportFile | ConvertFrom-Json -Depth 10
Write-Output "Exported $($bitwardenContent.items.Count) items from private vault."

foreach ($organization in $bitwardenOrganizations) {
    Out-File -FilePath (Join-Path -Path $exportDirectory -ChildPath "$($organization.id).json") `
        -InputObject (ConvertTo-Json -InputObject $organization -Depth 1)
    $exportFile = Join-Path -Path $exportDirectory -ChildPath "export-$($organization.id).json"
    $null = Invoke-Expression -Command "bw export --format json --organizationid $($organization.id) --output `"$exportFile`" "
    $bitwardenContent = Get-Content -Path $exportFile | ConvertFrom-Json -Depth 10
    Write-Output "Exported $($bitwardenContent.items.Count) items from organization $($organization.name) vault."
}
Remove-Variable bitwardenContent

$bitwardenData = Invoke-Expression "bw list items"  | ConvertFrom-Json -Depth 10
foreach ($bitwardenElement in $bitwardenData) {
    $itemDirectory = Join-Path -Path $exportDirectory -ChildPath ($bitwardenElement.id)
    if (Get-Member -InputObject $bitwardenElement -Name "attachments") {
        Write-Output "The element $($bitwardenElement.name) has $($bitwardenElement.attachments.Count) attachments."
        $null = New-Item -Path $itemDirectory -ItemType Directory
        foreach ($attachment in $bitwardenElement.attachments) {
            Write-Output "Found in entry $($bitwardenElement.name) attachment $($attachment.fileName) "
            $attachmentPath = Join-Path $itemDirectory ($attachment.fileName)
            $null = Invoke-Expression "bw get attachment $($attachment.id) --itemid $($bitwardenElement.id) --output `"$attachmentPath`"" --
        }
    }
}

Write-Output "Processed Downloads from all elements."


