#!/usr/bin/env pwsh
<#
.SYNOPSIS
Convenience wrapper for Repair-Tailscale function from CJC.Tailscale module.

.DESCRIPTION
Imports the CJC.Tailscale module and executes Repair-Tailscale with provided parameters.
This script provides backward compatibility with the original standalone script interface.

.PARAMETER Auto
If specified, automatically attempts to fix detected issues without prompting.

.PARAMETER Verbose
If specified, displays verbose output.

.EXAMPLE
.\Repair-Tailscale-Module.ps1

.EXAMPLE
.\Repair-Tailscale-Module.ps1 -Auto -Verbose
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Auto,

    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Import module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'CJC.Tailscale.psd1'
Import-Module -Path $modulePath -Force -Verbose:$Verbose

# Call the function with parameters
$params = @{
    Verbose = $Verbose
}

if ($Auto) { $params['Auto'] = $Auto }

Repair-Tailscale @params
