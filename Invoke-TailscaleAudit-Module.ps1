#!/usr/bin/env pwsh
<#
.SYNOPSIS
Convenience wrapper for Invoke-TailscaleAudit function from CJC.Tailscale module.

.DESCRIPTION
Imports the CJC.Tailscale module and executes Invoke-TailscaleAudit with provided parameters.
This script provides backward compatibility with the original standalone script interface.

.PARAMETER GenerateReport
If specified, generates timestamped JSON audit report.

.PARAMETER SSHUser
Username for SSH connections. Defaults to 'mathew.burkitt'.

.PARAMETER Verbose
If specified, displays verbose output.

.EXAMPLE
.\Invoke-TailscaleAudit-Module.ps1

.EXAMPLE
.\Invoke-TailscaleAudit-Module.ps1 -GenerateReport -Verbose
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport,

    [Parameter(Mandatory = $false)]
    [string]$SSHUser = "mathew.burkitt",

    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Import module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'CJC.Tailscale.psd1'
Import-Module -Path $modulePath -Force -Verbose:$Verbose

# Call the function with parameters
$params = @{
    SSHUser = $SSHUser
    Verbose = $Verbose
}

if ($GenerateReport) { $params['GenerateReport'] = $GenerateReport }

Invoke-TailscaleAudit @params
