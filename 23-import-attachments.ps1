#!/usr/bin/env pwsh
#Requires -Version 7.0

param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Provide the target path of the export script.")]
    [string]$ImportPath,
    [Parameter(HelpMessage = "In debug mode only the read information is printed to test, what will be done.")]
    [bool]$DebugMode = $true,
    [Parameter(HelpMessage = "The output file of the item mapping. The file will be created relative to the export path.")]
    [string]$ItemMapFile = "item-map.json"
)


# debug mode settings
if ($DebugMode) {
    $DebugPreference = 'Continue'
    Write-Debug "Debug Mode enabled"
}
    
. ./00-common.ps1

# check bitwarden unlocked
if ( Get-BitwardenStatusLocked ) {
    Write-Error "Bitwarden is locked! Please unlock your Bitwarden CLI." -Category ResourceUnavailable
    exit 31
}

# check valid import folder
if (-not (Test-Path $ImportPath -PathType Container)) {
    Write-Error "The path `"$ImportPath`" is not existing. Please provide a valid export path from the export script." -Category InvalidArgument
    exit 32
}

$ItemMapPath = Join-Path $ImportPath -ChildPath $ItemMapFile

# check valid mapping file
if (-not (Test-Path $ItemMapPath -PathType Leaf)) {
    Write-Error "The item file $ItemMapFile has not been found in `"$ItemMapPath`"! This is required for item mapping." -Category InvalidArgument
    exit 33
}

$AllExportedItems = Get-Content (Join-Path $ImportPath "item-map.json") | ConvertFrom-Json -Depth 10
$AttachmentCount = 0

foreach ($item in $AllExportedItems) {
    if ($item.attachments) {
        Write-Debug "Uploading attachments of $($item.name) ..."
        $AttachmentPath = Join-Path $ImportPath ($item.id)
        foreach ($attachment in $item.attachments) {
            $AttachmentCount++
            $AttachmentFile = Join-Path $AttachmentPath -ChildPath ($attachment.fileName)
            if ($DebugMode) {
                Write-Debug "bw create attachment --itemid $($item.{target-id}) --file `"$AttachmentFile`""
            } else {
                bw create attachment --itemid ($item.{target-id}) --file $AttachmentFile --pretty > attachment-import.json
            }
        }
    }
}
Write-Output "Uploaded $AttachmentCount file attachments for the vault."

