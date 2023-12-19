#Requires -Version 7.0

param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Provide the target path of the export script.")]
    [string]$ExportPath,
    [Parameter( HelpMessage = "In debug mode only the read information is printed to test, what will be done.")]
    [bool]$DebugMode = $true,
    [Parameter(HelpMessage = "Only the folders shall be imported and a folder mapping shall be created.")]
    [switch]$OnlyFolder,
    [Parameter(HelpMessage = "Only the private vault shall be imported. A folder mapping used from previous step. A item mapping is created.")]
    [switch]$OnlyPrivateVault,
    [Parameter(HelpMessage = "Only the file attachments shall be imported. A item mapping used from previous step.")]
    [switch]$OnlyAttachments,
    [Parameter(HelpMessage = "The output file of the folder mapping. The file will be created relative to the export path.")]
    [string]$FolderMapFile = "folder-map.json",
    [Parameter(HelpMessage = "The output file of the item mapping. The file will be created relative to the export path.")]
    [string]$ItemMapFile = "item-map.json"
)
    
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
    
# debug mode settings
if ($DebugMode) {
    $DebugPreference = 'Continue'
    Write-Debug "Debug Mode enabled"
}

# check bitwarden unlocked
$BitwardenStatus = Invoke-Expression "bw status"  | ConvertFrom-Json -Depth 1 | Select-Object -ExpandProperty status
if ( -not ($BitwardenStatus -eq "unlocked") ) {
    Write-Error "Bitwarden is not unlocked! Please unlock your Bitwarden CLI."
    Pause
    return 1
}
Remove-Variable BitwardenStatus
    
# check valid folder
if (-not (Test-Path $ExportPath -PathType Container)) {
    Write-Error "The path `"$ExportPath`" is not existing. Please provide a valid export path from the export script." -Category InvalidArgument
    exit 2
}
    
# TODO validate $FolderMapFile
$FolderMapPath = Join-Path $ExportPath -ChildPath $FolderMapFile
    
# Create all folders
if (-not ($OnlyPrivateVault)) {
        
    $FolderFile = Join-Path $ExportPath "export-list-folders.json"
    if (Test-Path $FolderFile -PathType Leaf) {

        $FolderContent = Get-Content $FolderFile | ConvertFrom-Json -Depth 2
        for ($i = 0; $i -lt $FolderContent.Length; $i++) {
            $FolderElement = $FolderContent[$i]
            if ($null -ne $FolderElement.id) {

                Write-Debug "Writing object $($FolderElement.object) name $($FolderElement.name) with id $($FolderElement.id)."
                ConvertTo-Json $FolderElement -Depth 1 | ForEach-Object {
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($_)
                    $baseEncoded = [System.Convert]::ToBase64String($bytes)
                    if ($DebugMode) {
                        Write-Debug "bw create folder $baseEncoded"
                    }
                    else {
                        # TODO create folder map
                        $NewFolder = bw create folder $baseEncoded | ConvertFrom-Json -Depth 1
                        Add-Member -InputObject $FolderContent[$i] -MemberType NoteProperty -Name "target-id" -Value $NewFolder.id
                        Remove-Variable NewFolder
                    }
                    Remove-Variable bytes
                    Remove-Variable baseEncoded
                }
            }
            Remove-Variable FolderElement
        }

        # store the new mapping
        ConvertTo-Json $FolderContent -Depth 2 | Out-File $FolderMapPath
        Write-Output "All folders processed. Folder map written to $FolderMapFile ..."
    }
    else {
        Write-Error "The folder file `"$FolderFile`" is missing."
        exit 3
    }
    Remove-Variable FolderFile
}
else {
    if (-not (Test-Path $FolderMapPath -PathType Leaf)) {
        Write-Error "The file $FolderMapFile has not been found in `"$FolderMapPath`"!"
        exit 4
    }
    $FolderContent = Get-Content $FolderMapPath | ConvertFrom-Json -Depth 2
}


if (-not ($OnlyFolder)) {
    # Read all personal items
    $ExportPrivate = Get-Content (Join-Path $ExportPath "export-private.json") | ConvertFrom-Json -Depth 10
    foreach ($BitwardenItem in $ExportPrivate.items) {
        Write-Debug "Processing Item $($BitwardenItem.name)"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $BitwardenItem -Depth 8))
        $baseEncoded = [System.Convert]::ToBase64String($bytes)
        if ($DebugMode) {
            Write-Debug "bw create item $baseEncoded"
        }
        else {
            # TODO create item map
            $null = bw create item $baseEncoded
        }
    }
}

# Match all organizations

# add attachments to all items

if ($false) {
    foreach ($element in Get-ChildItem $ExportPath -Directory) {
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

