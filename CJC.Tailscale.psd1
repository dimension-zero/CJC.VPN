@{
    # Module manifest for CJC.Tailscale

    RootModule           = 'CJC.Tailscale.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '4a5b8c7d-2e1f-4a3b-8e9f-1a2b3c4d5e6f'
    Author               = 'CJC Infrastructure'
    Description          = 'PowerShell module for managing Tailscale VPN installation, repair, and auditing'

    # PowerShell Version Requirements
    PowerShellVersion    = '7.2'
    CompatiblePSEditions = @('Core')

    # Functions to export from this module
    FunctionsToExport    = @(
        'Install-Tailscale'
        'Repair-Tailscale'
        'Invoke-TailscaleAudit'
    )

    # Cmdlets to export from this module
    CmdletsToExport      = @()

    # Variables to export from this module
    VariablesToExport    = @()

    # Aliases to export from this module
    AliasesToExport      = @()

    # Module dependencies
    RequiredModules      = @()

    # Required assemblies
    RequiredAssemblies   = @()

    # Format files (.ps1xml) to load when this module is imported
    FormatsToProcess     = @()

    # Type files (.ps1xml) to load when this module is imported
    TypesToProcess       = @()

    # Script files (.ps1) that run in the caller's session state before the module is imported
    ScriptsToProcess     = @()

    # Modules to import as nested modules
    NestedModules        = @()

    # HelpInfo URI for this module
    HelpInfoURI          = ''

    # Default prefix for commands exported from this module
    DefaultCommandPrefix = ''

    # Functions that should be made private
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module
            Tags       = @('Tailscale', 'VPN', 'SSH', 'Infrastructure', 'Automation')

            # License for this module
            LicenseUri = ''

            # Project URI
            ProjectUri = 'https://github.com/dimension-zero/CJC.VPN'

            # Release notes
            ReleaseNotes = @'
Version 1.0.0
- Initial release
- Install-Tailscale: Cross-platform SSH and Tailscale installation
- Repair-Tailscale: Diagnostics and repair workflow
- Invoke-TailscaleAudit: Comprehensive testing of all Tailscale machines
- Modular architecture with type-safe Result<T> pattern
- PSScriptAnalyzer configuration for code quality
- Pester tests for critical paths
- Pre-commit hook for validation
'@
        }
    }
}
