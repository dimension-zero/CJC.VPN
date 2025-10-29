<#
.SYNOPSIS
Writes timestamped, color-coded log messages to the console.

.PARAMETER Message
The message text to log.

.PARAMETER Level
The log level: INFO, WARN, ERROR, SUCCESS, TEST, DEBUG.

.PARAMETER NoNewline
If specified, does not append a newline after the message.

.EXAMPLE
Write-Log "Operation completed successfully" -Level SUCCESS

.EXAMPLE
Write-Log "An error occurred" -Level ERROR
#>

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "TEST", "DEBUG")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [switch]$NoNewline
    )

    process {
        $timestamp = Get-Date -Format "HH:mm:ss"
        $colors = @{
            INFO    = "White"
            WARN    = "Yellow"
            ERROR   = "Red"
            SUCCESS = "Green"
            TEST    = "Cyan"
            DEBUG   = "Gray"
        }

        $params = @{
            Object          = "[$timestamp] [$Level] $Message"
            ForegroundColor = $colors[$Level]
        }

        if ($NoNewline) {
            $params['NoNewline'] = $true
        }

        Write-Host @params
    }
}
