# I implement this script with latest Powershell available an do not intend to test older ones. It may or may be not working for Powershell 5.
#Requires -Version 7.0

# https://learn.microsoft.com/de-de/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-7.4
# ensure the output is UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function New-ExportFolder {
    $exportFolderName = "export-$(Get-Date -Format "yyyy-MM-dd-HH-mm")"
    $exportDirectory = Join-Path -Path (Get-Location) -ChildPath $exportFolderName
    New-Item -Path $exportDirectory -ItemType Directory
}

# check bitwarden unlocked
$bitwardenData = Invoke-Expression "bw status"  | ConvertFrom-Json -Depth 10
if ( -not (($bitwardenData.status) -eq "unlocked") ) {
    Write-Error "Bitwarden is not unlocked! Please unlock your Bitwarden CLI."
    Pause
    return -1
}

# create the export directory
$exportDirectory = New-ExportFolder

# Read data from Bitwarden
$bitwardenData = Invoke-Expression "bw list items"  | ConvertFrom-Json -Depth 10
foreach ($bitwardenElement in $bitwardenData) {
    $itemDirectory = Join-Path -Path $exportDirectory -ChildPath ($bitwardenElement.id)
    $null = New-Item -Path $itemDirectory -ItemType Directory
    Out-File -FilePath (Join-Path -Path $itemDirectory -ChildPath "$($bitwardenElement.id).json") `
      -InputObject (ConvertTo-Json -InputObject $bitwardenElement -Depth 10)
    foreach ($attachment in $bitwardenElement.attachments) {
        Write-Output "Found in entry $($bitwardenElement.name) attachment $($attachment.fileName) "
        $attachmentPath = Join-Path $itemDirectory ($attachment.fileName)
        $null = Invoke-Expression "bw get attachment $($attachment.id) --itemid $($bitwardenElement.id) --output `"$attachmentPath`"" --
    }
}
Write-Output "Processed $($bitwardenData.Count) items in total."


