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
if (-not (Test-Path $ImportPath -PathType Container)) {
    Write-Error "The path `"$ImportPath`" is not existing. Please provide a valid export path from the export script." -Category InvalidArgument
    exit 2
}
    
# TODO validate
$FolderMapPath = Join-Path $ImportPath -ChildPath $FolderMapFile
$ItemMapPath = Join-Path $ImportPath -ChildPath $ItemMapFile

function ConvertTo-Base64 {
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, HelpMessage = "This UTF-8 string value shall be transformed into a Base64 coding.")]
        [string] $InputString
    )

    process {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        $baseEncoded = [System.Convert]::ToBase64String($bytes)
        return $baseEncoded
    }
}

function Find-MapValue {
    param (
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "This is an array of Powershell object with `"id`" as key and `"target-id`" as value")]
        [psobject[]] $Mapping,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "This UUID will be searched in the mapping array for the target UUID.")]
        [string] $SearchUuid
    )

    process {

        foreach ($item in $Mapping) {
            if ($item.id -eq $SearchUuid) {
                return $item.'target-id'
            }
        }
        Write-Warning "No mapping found for $SearchUuid in $($Mapping.Count) search items."
        return $null
    }
}

# Create all folders. Accepts $OnlyFolder.
if (-not ($OnlyPrivateVault -or $OnlyAttachments)) {
        
    $FolderFile = Join-Path $ImportPath "export-list-folders.json"
    Write-Output "Reading exported folders from `"export-list-folders.json`"."
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
                        Write-Debug "  bw create folder $baseEncoded"
                    }
                    else {
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

        # store the new folder mapping
        if (-not $DebugMode) {
            ConvertTo-Json $FolderContent -Depth 2 | Out-File $FolderMapPath
        }
        Write-Output "... all folders processed. Folder map written to `"$FolderMapFile`""
    }
    else {
        Write-Error "The folder file `"$FolderFile`" is missing."
        exit 3
    }
    Remove-Variable FolderFile
}
# If folder mapping is not in memory it must be read from file. Not required if only attachments need processing.
elseif (-not $OnlyAttachments) {
    if (-not (Test-Path $FolderMapPath -PathType Leaf)) {
        Write-Error "The file $FolderMapFile has not been found in `"$FolderMapPath`"!"
        exit 4
    }
    $FolderContent = Get-Content $FolderMapPath | ConvertFrom-Json -Depth 2
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
            $BitwardenItem = $BitwardenItem | Select-Object -Property * -ExcludeProperty organizationId
        }

        if ($BitwardenItem.folderId) { 
            $BitwardenItem.folderId = $BitwardenItem.folderId | Find-MapValue $FolderContent 
        }
        $baseEncoded = ConvertTo-Json $BitwardenItem -Depth 9 | ConvertTo-Base64 
        if ($DebugMode) {
            Write-Debug "  bw create item $baseEncoded"
        }
        else {
            $NewItem = bw create item $baseEncoded | ConvertFrom-Json -Depth 10
            Add-Member -InputObject $ExportAll[$i] -MemberType NoteProperty -Name "target-id" -Value $NewItem.id
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

if ($false) {
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

