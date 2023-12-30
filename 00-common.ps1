#Requires -Version 7.0

# Common functions for import and export steps.
#$PSDefaultParameterValues['*:Encoding'] = 'utf8'

### TODO improve logging by writing it to a file
## example input
#$outputFile = "output.log"
#$message = "Hello, world!"
## Display on console and append to file
#Write-Host $message
#$message | Tee-Object -Append -FilePath $outputFile


function ConvertTo-Base64 {
    [OutputType([string])]
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
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "This is an array of Powershell object with `"id`" as key and `"target-id`" as value")]
        [psobject[]] $Mapping,
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, HelpMessage = "This UUID will be searched in the mapping array for the target UUID.")]
        [AllowEmptyString()]
        [string] $SearchUuid
    )

    process {

        if ($null -eq $SearchUuid) {
            return $null
        }

        foreach ($item in $Mapping) {
            if ($item.id -eq $SearchUuid) {
                return $item.'target-id'
            }
        }
        Write-Warning "No mapping found for $SearchUuid in $($Mapping.Count) search items."
        return $null
    }
}

function Get-FirstObjectWithName {
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "A list of objects with the property `"name`" to be searched for the given value.")]
        [PSObject[]]$ObjectArray,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "The `"name`" to be searched in the array.")]
        [string]$Name
    )
    $ObjectArray | Where-Object { $_.name -eq $Name } | Select-Object -First 1
}


function Get-BitwardenStatusLocked {
    [OutputType([bool])]
    $BitwardenStatus = Invoke-Expression "bw status"  | ConvertFrom-Json -Depth 1 | Select-Object -ExpandProperty status
    if ( -not ($BitwardenStatus -eq "unlocked") ) { return $true }
    return $false
}