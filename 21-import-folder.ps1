#!/usr/bin/env pwsh
#Requires -Version 7.0

param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Provide the target path of the export script.")]
    [string]$ImportPath,
    [Parameter( HelpMessage = "In debug mode only the read information is printed to test, what will be done.")]
    [bool]$DebugMode = $true,
    [Parameter(HelpMessage = "The output file of the folder mapping. The file will be created relative to the export path.")]
    [string]$FolderMapFile = "folder-map.json"
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
    Write-Error "Bitwarden is not unlocked! Please unlock your Bitwarden CLI." -Category ResourceUnavailable
    exit 11
}

# check valid folder
if (-not (Test-Path $ImportPath -PathType Container)) {
    Write-Error "The path `"$ImportPath`" is not existing. Please provide a valid export path from the export script." -Category InvalidArgument
    exit 12
}

# TODO validate
$FolderMapPath = Join-Path $ImportPath -ChildPath $FolderMapFile


$FolderFile = Join-Path $ImportPath "export-list-folders.json"
Write-Output "Reading exported folders from `"export-list-folders.json`"."
if (Test-Path $FolderFile -PathType Leaf) {

    $FolderContent = Get-Content $FolderFile | ConvertFrom-Json -Depth 2
    for ($i = 0; $i -lt $FolderContent.Length; $i++) {
        $FolderElement = $FolderContent[$i]
        if ($null -ne $FolderElement.id) {

            Write-Debug "Writing object $($FolderElement.object) name $($FolderElement.name) with id $($FolderElement.id)."
            ConvertTo-Json $FolderElement -Depth 1 | ConvertTo-Base64 | ForEach-Object {
                if ($DebugMode) {
                    Write-Debug "  bw create folder $_"
                }
                else {
                    $NewFolder = bw create folder $_ | ConvertFrom-Json -Depth 1
                    Add-Member -InputObject $FolderContent[$i] -MemberType NoteProperty -Name "target-id" -Value $NewFolder.id
                    Remove-Variable NewFolder
                }
            }
        }
        Remove-Variable FolderElement
    }

    # store the new folder mapping
    if (-not $DebugMode) {
        ConvertTo-Json $FolderContent -Depth 2 | Out-File $FolderMapPath
    }
    Write-Output "... all $($FolderContent.Length) folders processed. Folder map written to `"$FolderMapFile`""
    Remove-Variable FolderContent
    exit 0
}
else {
    Write-Error "Folder input `"$FolderFile` not found! This is required to import folder." -Category ResourceUnavailable
    exit 13
}