#Requires -Version 7.0

param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Provide the target path of the export script.")]
    [string]$Path
)

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

if (-not (Test-Path $Path -PathType Container)) {
    Write-Error "The path `"$Path`" is not existing. Please provide a valid export path from the export script."
    exit -1
}

foreach ($element in Get-ChildItem $Path -Directory) {
    $name = $element.Name
    $itemPath = Join-Path $element "$name.json"
    if (-not (Test-Path $itemPath -PathType Leaf)) {
        Write-Warning "The folder $name does not contain a Bitwarden item file $name.json. Skipping!"
        continue
    }
    Write-Output "Processing element $name"
    $bitwardenElement = Get-Content $itemPath | ConvertFrom-Json -Depth 10
    foreach ($attachment in $bitwardenElement.attachments) {
        Write-Output "Importing `"$($attachment.fileName)`" for entry $($bitwardenElement.name)"
    }


}

