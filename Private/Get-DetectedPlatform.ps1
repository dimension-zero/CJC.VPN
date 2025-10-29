<#
.SYNOPSIS
Detects the current operating system platform.

.DESCRIPTION
Determines if the system is running Windows, macOS, or Linux by examining
PowerShell runtime variables.

.OUTPUTS
System.String - One of: "Windows", "macOS", or "Linux"

.EXAMPLE
$platform = Get-DetectedPlatform
Write-Host "Running on: $platform"
#>

function Get-DetectedPlatform {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($PSVersionTable.Platform -eq "Unix") {
        if ($IsMacOS) {
            return "macOS"
        }
        elseif ($IsLinux) {
            return "Linux"
        }
        else {
            return "Unix"
        }
    }
    else {
        return "Windows"
    }
}
