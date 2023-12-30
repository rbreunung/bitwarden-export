#!/usr/bin/env pwsh
#Requires -Version 7.0

param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Provide the target path of the export script.")]
    [string]$ImportPath,
    [Parameter(HelpMessage = "In debug mode only the read information is printed to test, what will be done.")]
    [bool]$DebugMode = $true,
    [Parameter(HelpMessage = "Only the private vault shall be imported. A folder mapping used from previous step. A item mapping is created.")]
    [switch]$OnlyPrivateVault,
    [Parameter(HelpMessage = "The input file for the folder mapping. The file will be read relative to the export path.")]
    [string]$FolderMapFile = "folder-map.json",
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
    Write-Error "Bitwarden is not unlocked! Please unlock your Bitwarden CLI." -Category ResourceUnavailable
    exit 21
}

# check valid folder
if (-not (Test-Path $ImportPath -PathType Container)) {
    Write-Error "The path `"$ImportPath`" is not existing. Please provide a valid export path from the export script." -Category InvalidArgument
    exit 22
}

# check folder mapping file exists
$FolderMapPath = Join-Path $ImportPath -ChildPath $FolderMapFile
if (-not (Test-Path $FolderMapPath -PathType Leaf)) {
    Write-Error "The folder file $FolderMapFile has not been found in `"$FolderMapPath`"! This is required for folder to item mapping."
    exit 23
}

# read folder mapping
$FolderContent = Get-Content $FolderMapPath | ConvertFrom-Json -Depth 2
# item output mapping
$ItemMapPath = Join-Path $ImportPath -ChildPath $ItemMapFile


if ($OnlyPrivateVault) {
    Write-Output "Reading private items from `"export-list-items.json`"."
}
else {
    Write-Output "Reading all items from `"export-list-items.json`"."
}
$AllExportedItems = Get-Content (Join-Path $ImportPath "export-list-items.json") | ConvertFrom-Json -Depth 10
$SkipCount = 0
Write-Output "Expect to process $($AllExportedItems.Length) items."
for ($i = 0; $i -lt $AllExportedItems.Length; $i++) {
    if ((0 -eq ($i % 20)) -and (-not (0 -eq $i))) {
        Write-Output "  ... $i items processed so far ..."
    }
    $BitwardenItem = $AllExportedItems[$i]
    if ($OnlyPrivateVault -and (-not ($null -eq $BitwardenItem.organizationId))) {
        Write-Debug "Skip organization item $($BitwardenItem.name) because of `"private items only`" import..."
        $SkipCount++
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
    }
    else {
        $NewItem = bw create item $baseEncoded | ConvertFrom-Json -Depth 10
        Add-Member -InputObject $AllExportedItems[$i] -MemberType NoteProperty -Name "target-id" -Value $NewItem.id
        Remove-Variable NewItem
        break
    }
}
# store the new item mapping
if (-not $DebugMode) {
    ConvertTo-Json $AllExportedItems -Depth 10 | Out-File $ItemMapPath
}
Write-Output "... all $($AllExportedItems.Count) items processed. $SkipCount of those were skipped. Item map written to `"$ItemMapPath`""

Remove-Variable BitwardenItem
Remove-Variable FolderContent
Remove-Variable FolderMapPath
Remove-Variable AllExportedItems
Remove-Variable ItemMapPath