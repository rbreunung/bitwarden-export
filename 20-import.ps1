#!/usr/bin/env pwsh
#Requires -Version 7.0

param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Provide the target path of the export script.")]
    [string]$ImportPath,
    [Parameter( HelpMessage = "In debug mode only the read information is printed to test, what will be done.")]
    [bool]$DebugMode = $true,
    [Parameter(HelpMessage = "Only the folders shall be imported and a folder mapping shall be created.")]
    [switch]$OnlyFolder,
    [Parameter(HelpMessage = "Only the private vault shall be imported. A folder mapping used from previous step. A item mapping is created.")]
    [switch]$OnlyPrivateVault,
    [Parameter(HelpMessage = "Only all items shall be imported. A folder mapping used from previous step. A item mapping is created.")]
    [switch]$OnlyItems,
    [Parameter(HelpMessage = "Only the file attachments shall be imported. A item mapping used from previous step.")]
    [switch]$OnlyAttachments,
    [Parameter(HelpMessage = "The output file of the folder mapping. The file will be created relative to the export path.")]
    [string]$FolderMapFile = "folder-map.json",
    [Parameter(HelpMessage = "The output file of the item mapping. The file will be created relative to the export path.")]
    [string]$ItemMapFile = "item-map.json"
)

$PSDefaultParameterValues['*:Encoding'] = 'utf8'
. ./00-common.ps1

# debug mode settings
if ($DebugMode) {
    $DebugPreference = 'Continue'
    Write-Debug "Debug Mode enabled"
}

# check bitwarden unlocked
if ( Get-BitwardenStatusLocked ) {
    Write-Error "Bitwarden is not unlocked! Please unlock your Bitwarden CLI."
    Pause
    exit 1
}

# check valid folder
if (-not (Test-Path $ImportPath -PathType Container)) {
    Write-Error "The path `"$ImportPath`" is not existing. Please provide a valid export path from the export script." -Category InvalidArgument
    Pause
    exit 2
}

$ItemMapPath = Join-Path $ImportPath -ChildPath $ItemMapFile

# Create all folders. Accepts $OnlyFolder.
if (-not ($OnlyPrivateVault -or $OnlyItems -or $OnlyAttachments)) {

    $null = Invoke-Expression "./21-import-folder.ps1 -ImportPath $ImportPath -DebugMode $DebugMode -FolderMapFile $FolderMapFile" 
}

# Read all personal items. Accepts $OnlyPrivateVault
if (-not ($OnlyFolder -or $OnlyAttachments)) {

    $null = Invoke-Expression "./22-import-items.ps1 -ImportPath $ImportPath -DebugMode $DebugMode -OnlyPrivateVault $OnlyPrivateVault -FolderMapFile $FolderMapFile -ItemMapFile $ItemMapFile"
}

# Match all organizations

# add attachments to all items
if ($OnlyAttachments) {
    if (-not (Test-Path $ItemMapPath -PathType Leaf)) {
        Write-Error "The file $ItemMapFile has not been found in `"$ItemMapPath`"! This is required for item to attachment mapping."
        exit 5
    }
    $ExportAll = Get-Content $ItemMapPath | ConvertFrom-Json -Depth 10
}


if (-not ($OnlyFolder -or $OnlyPrivateVault -or $OnlyItems)) {
    foreach ($element in Get-ChildItem $ImportPath -Directory) {
        $name = $element.Name
        $itemPath = Join-Path $element "$name.json"
        if (-not (Test-Path $itemPath -PathType Leaf)) {
            #        Write-Debug "The folder $name does not contain a Bitwarden item file $name.json. Skipping!"
            continue
        }
        Write-Output "Processing element $name"
        $bitwardenElement = Get-Content $itemPath | ConvertFrom-Json -Depth 10
        foreach ($attachment in $bitwardenElement.attachments) {
            #       Write-Output "Importing `"$($attachment.fileName)`" for entry $($bitwardenElement.name)"
        }


    }
}

