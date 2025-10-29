# CJC.Tailscale PowerShell Module Loader
# Loads classes, private functions, and public functions

Set-StrictMode -Version Latest

# ==================== LOAD CLASSES ====================
$classes = @(Get-ChildItem -Path "$PSScriptRoot\Classes\*.ps1" -ErrorAction SilentlyContinue)
foreach ($class in $classes) {
    try {
        . $class.FullName
    }
    catch {
        Write-Error "Failed to load class $($class.Name): $_"
    }
}

# ==================== LOAD PRIVATE FUNCTIONS ====================
$privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)
foreach ($private in $privateFunctions) {
    try {
        . $private.FullName
    }
    catch {
        Write-Error "Failed to load private function $($private.Name): $_"
    }
}

# ==================== LOAD PUBLIC FUNCTIONS ====================
$publicFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
foreach ($public in $publicFunctions) {
    try {
        . $public.FullName
    }
    catch {
        Write-Error "Failed to load public function $($public.Name): $_"
    }
}

# ==================== EXPORT PUBLIC FUNCTIONS ====================
$functionNames = @()
foreach ($public in $publicFunctions) {
    $functionName = $public.BaseName
    $functionNames += $functionName
}

Export-ModuleMember -Function $functionNames
