#!/usr/bin/env pwsh
<#
.SYNOPSIS
Convenience wrapper for Install-Tailscale function from CJC.Tailscale module.

.DESCRIPTION
Imports the CJC.Tailscale module and executes Install-Tailscale with provided parameters.
This script provides backward compatibility with the original standalone script interface.

.PARAMETER Platform
Specify the platform explicitly (Windows, macOS, Linux). If not specified, auto-detects.

.PARAMETER SSHUser
Username for SSH connections. Defaults to 'mathew.burkitt'.

.PARAMETER SkipSSH
If specified, skips SSH installation.

.PARAMETER SkipProfile
If specified, skips PowerShell profile setup.

.EXAMPLE
.\Install-Tailscale-Module.ps1

.EXAMPLE
.\Install-Tailscale-Module.ps1 -SkipSSH -Verbose
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Windows", "macOS", "Linux")]
    [string]$Platform,

    [Parameter(Mandatory = $false)]
    [string]$SSHUser = "mathew.burkitt",

    [Parameter(Mandatory = $false)]
    [switch]$SkipSSH,

    [Parameter(Mandatory = $false)]
    [switch]$SkipProfile,

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

if ($Platform) { $params['Platform'] = $Platform }
if ($SSHUser) { $params['SSHUser'] = $SSHUser }
if ($SkipSSH) { $params['SkipSSH'] = $SkipSSH }
if ($SkipProfile) { $params['SkipProfile'] = $SkipProfile }

Install-Tailscale @params
