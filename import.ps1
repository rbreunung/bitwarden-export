#Requires -Version 7.0

param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Who do you want to greet?")]
    [string]$Path
)

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

if (-not (Test-Path $Path -PathType Container)) {
    Write-Error "The path $Path is not existing. Please provide a valid export path from the export script."
    exit -1
}

foreach ($element in Get-ChildItem $Path -Directory) {
    Write-Output "Processing element $element"
}

