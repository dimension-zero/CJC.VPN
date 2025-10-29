@{
    # PSScriptAnalyzer Configuration for CJC.Tailscale Module
    # Provides static analysis and code quality validation

    # Severity levels to report
    Severity = @('Error', 'Warning')

    # Rules that will NOT be enforced
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'           # Write-Host is acceptable for CLI tools
        'PSAvoidUsingInvokeExpression'    # Not used in this codebase
        'PSUseBOMForUnicodeEncodedFile'   # Not applicable
        'PSAvoidUsingComputerNameHardcoded'  # Acceptable for single-user projects
    )

    # Rules with specific configuration
    Rules = @{
        # Ensure compatibility with PowerShell Core 7.2+
        PSUseCompatibleCommands = @{
            Enable         = $true
            TargetProfiles = @(
                'win-8.1_x64_7.2.0_core_2.0.0_x64'
                'ubuntu_x64_7.2.0_core_2.0.0_x64'
            )
        }

        # Function naming conventions - Verb-Noun format
        PSUseApprovedVerbs = @{
            Enable = $true
        }

        # Require comment-based help for public functions
        PSProvideCommentBasedHelp = @{
            Enable                   = $true
            ExportedOnly             = $true
            BlockComment             = $true
            VSCodeSnippetCorrection  = $false
            Placement                = 'Before'
        }

        # Parameter validation
        PSAvoidDefaultValueSwitchParameter = @{
            Enable = $true
        }

        # Avoid using positional parameters beyond a certain number
        PSAvoidUsingPositionalParameters = @{
            Enable         = $true
            CommandAstType = 'Ast'
            Severity       = 'Warning'
        }

        # Use proper exception handling
        PSUseProcessBlockForPipelineCommand = @{
            Enable = $true
        }

        # Consistent naming of variables
        PSUseCmdletApprovedVerbs = @{
            Enable = $true
        }

        # Proper use of ShouldProcess
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $false  # Disabled for simple utilities
        }

        # Consistent formatting
        PSAlignAssignmentStatement = @{
            Enable         = $false  # Too restrictive
            CheckHashtable = $false
        }

        # File length restrictions
        PSAvoidLongLines = @{
            Enable      = $true
            MaximumLineLength = 120
        }

        # Mandatory parameters first
        PSPlaceOpenBrace = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        # Use correct case for operators
        PSUseCorrectCasing = @{
            Enable = $true
        }

        # Variable names - should use camelCase or PascalCase consistently
        PSUseConsistentWhitespace = @{
            Enable              = $true
            CheckInnerBrace     = $true
            CheckOpenBrace      = $true
            CheckOpenParen      = $true
            CheckOperator       = $true
            CheckPipe           = $true
            CheckPipelineIndentation = 'Inconsistent'
            CheckSeparator      = $true
        }
    }

    # Include/exclude specific rules
    IncludeRules = @()
}
