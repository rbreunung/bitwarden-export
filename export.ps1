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
## Export private password data
$exportFile = Join-Path -Path $exportDirectory -ChildPath "export-private.json"
$null = Invoke-Expression -Command "bw export --format json --output `"$exportFile`" "
$bitwardenContent = Get-Content -Path $exportFile | ConvertFrom-Json -Depth 10
Write-Output "Exported $($bitwardenContent.items.Count) items from private vault."

## Export organization listing
$exportFile = Join-Path -Path $exportDirectory -ChildPath "export-list-organizations.json"
bw list organizations > $exportFile
$bitwardenOrganizations = Get-Content $exportFile | ConvertFrom-Json -Depth 2
Write-Output "Exported $($bitwardenOrganizations.Count) organizations total."

## Export folder listing
$exportFile = Join-Path -Path $exportDirectory -ChildPath "export-list-folders.json"
bw list folders > $exportFile
$bitwardenfolders = Get-Content $exportFile | ConvertFrom-Json -Depth 2
Write-Output "Exported $($bitwardenfolders.Count) folders total."

## Export folder items
$exportFile = Join-Path -Path $exportDirectory -ChildPath "export-list-items.json"
bw list items > $exportFile
$bitwardenItems = Get-Content $exportFile | ConvertFrom-Json -Depth 10
Write-Output "Exported $($bitwardenItems.Count) items total."

## export orgaization password data
foreach ($organization in $bitwardenOrganizations) {
    $exportFile = Join-Path -Path $exportDirectory -ChildPath "export-$($organization.id).json"
    $null = Invoke-Expression -Command "bw export --format json --organizationid $($organization.id) --output `"$exportFile`" "
    $bitwardenContent = Get-Content -Path $exportFile | ConvertFrom-Json -Depth 10
    Write-Output "Exported $($bitwardenContent.items.Count) items from organization $($organization.name) vault."
}
Remove-Variable bitwardenContent

## export attachments
foreach ($bitwardenElement in $bitwardenItems) {
    $itemDirectory = Join-Path -Path $exportDirectory -ChildPath ($bitwardenElement.id)
    if (Get-Member -InputObject $bitwardenElement -Name "attachments") {
        Write-Debug "The element $($bitwardenElement.name) has $($bitwardenElement.attachments.Count) attachments." 
        $null = New-Item -Path $itemDirectory -ItemType Directory
        foreach ($attachment in $bitwardenElement.attachments) {
            Write-Debug "Found in entry $($bitwardenElement.name) attachment $($attachment.fileName) "
            $attachmentPath = Join-Path $itemDirectory ($attachment.fileName)
            $null = Invoke-Expression "bw get attachment $($attachment.id) --itemid $($bitwardenElement.id) --output `"$attachmentPath`"" --
        }
    }
}

Write-Output "Processed Downloads from all elements."


