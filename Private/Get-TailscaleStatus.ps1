<#
.SYNOPSIS
Gets the current Tailscale status output.

.DESCRIPTION
Executes 'tailscale status' command and returns the output or null if the command fails.

.OUTPUTS
System.String[] - Lines from tailscale status output, or $null if command failed.

.EXAMPLE
$status = Get-TailscaleStatus
if ($status) {
    $status | Write-Host
}
#>

function Get-TailscaleStatus {
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param()

    try {
        $status = @(tailscale status 2>&1)
        if ($status -and $status.Count -gt 0) {
            return $status
        }
        return $null
    }
    catch {
        Write-Log "Failed to get Tailscale status: $_" -Level ERROR
        return $null
    }
}
