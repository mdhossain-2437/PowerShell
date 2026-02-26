@{
GUID = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
Author = "PowerShell"
CompanyName = "Microsoft Corporation"
Copyright = "Copyright (c) Microsoft Corporation."
Description = "PowerShell module for Hyper terminal integration. Provides functions to detect, configure, and manage Hyper terminal plugins and settings."
ModuleVersion = "1.0.0"
CompatiblePSEditions = @("Core")
PowerShellVersion = "7.0"
RootModule = "Microsoft.PowerShell.HyperTerminal.psm1"
FunctionsToExport = @(
    'Test-HyperTerminal',
    'Get-HyperPlugin',
    'Install-HyperPlugin',
    'Remove-HyperPlugin',
    'Get-HyperConfiguration',
    'Set-HyperConfiguration',
    'Enable-HyperShellIntegration'
)
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('Hyper', 'Terminal', 'HyperTerminal', 'Plugin', 'Integration')
        ProjectUri = 'https://github.com/PowerShell/PowerShell'
        LicenseUri = 'https://github.com/PowerShell/PowerShell/blob/master/LICENSE.txt'
    }
}
}
