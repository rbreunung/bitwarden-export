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

# TODO validate
$FolderMapPath = Join-Path $ImportPath -ChildPath $FolderMapFile
$ItemMapPath = Join-Path $ImportPath -ChildPath $ItemMapFile

# Create all folders. Accepts $OnlyFolder.
if (-not ($OnlyPrivateVault -or $OnlyItems -or $OnlyAttachments)) {

    $null = Invoke-Expression "./21-import-folder.ps1 -ImportPath $ImportPath -WhatIf $DebugMode -FolderMapFile $FolderMapFile" 
}

# Read all personal items. Accepts $OnlyPrivateVault
if (-not ($OnlyFolder -or $OnlyAttachments)) {
    if ($OnlyPrivateVault) {
        Write-Output "Reading private items from `"export-list-items.json`"."
    }
    else {
        Write-Output "Reading all items from `"export-list-items.json`"."
    }
    $ExportAll = Get-Content (Join-Path $ImportPath "export-list-items.json") | ConvertFrom-Json -Depth 10
    for ($i = 0; $i -lt $ExportAll.Length; $i++) {
        if ((0 -eq ($i % 20)) -and (-not (0 -eq $i))) {
            Write-Output "  ... $i items processed so far ..."
        }
        $BitwardenItem = $ExportAll[$i]
        if ($OnlyPrivateVault -and ($null -eq $BitwardenItem.organizationId)) {
            Write-Debug "Skip organization item $($BitwardenItem.name) because of `"private items only`" import..."
            continue
        }
        else {
            Write-Debug "Processing Item $($BitwardenItem.name)..."
            # delete organizationId as we do not handle it for now - TODO more organization support
            $BitwardenItem = $BitwardenItem | Select-Object -Property * -ExcludeProperty organizationId
        }

        $BitwardenItem.folderId = Find-MapValue $FolderContent $BitwardenItem.folderId
        $baseEncoded = ConvertTo-Json $BitwardenItem -Depth 9 | ConvertTo-Base64 
        if ($DebugMode) {
            Write-Debug "  bw create item $baseEncoded"
            break
        }
        else {
            $NewItem = bw create item $baseEncoded | ConvertFrom-Json -Depth 10
            Add-Member -InputObject $ExportAll[$i] -MemberType NoteProperty -Name "target-id" -Value $NewItem.id
            break
        }
    }
    # store the new item mapping
    if (-not $DebugMode) {
        ConvertTo-Json $ExportAll -Depth 10 | Out-File $ItemMapPath
    }
    Write-Output "... all $($ExportAll.Count) items processed. Item map written to `"$ItemMapPath`""
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

