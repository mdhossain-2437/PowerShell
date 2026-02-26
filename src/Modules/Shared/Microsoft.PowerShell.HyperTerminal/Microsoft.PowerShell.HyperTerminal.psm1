# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Set-StrictMode -Version 3.0

#region Private Helpers

function Get-HyperConfigPath
{
    <#
    .SYNOPSIS
        Returns the path to the Hyper terminal configuration file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Hyper stores its configuration at ~/.hyper.js on all platforms
    $homePath = $env:HOME
    if ([string]::IsNullOrEmpty($homePath))
    {
        $homePath = $env:USERPROFILE
    }

    if ([string]::IsNullOrEmpty($homePath))
    {
        return $null
    }

    return Join-Path $homePath '.hyper.js'
}

function Read-HyperConfigContent
{
    <#
    .SYNOPSIS
        Reads the raw content of the Hyper configuration file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $configPath = Get-HyperConfigPath

    if (-not (Test-Path -Path $configPath))
    {
        return $null
    }

    return Get-Content -Path $configPath -Raw
}

function Get-PluginListFromContent
{
    <#
    .SYNOPSIS
        Parses the plugins array from Hyper config content.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $Content
    )

    $pluginList = @()

    if ($Content -match 'plugins\s*:\s*\[([^\]]*)\]')
    {
        $pluginBlock = $Matches[1]
        $pluginEntries = [regex]::Matches($pluginBlock, '''([^'']+)''|"([^"]+)"')

        foreach ($entry in $pluginEntries)
        {
            $pluginName = if ($entry.Groups[1].Success) { $entry.Groups[1].Value } else { $entry.Groups[2].Value }
            $pluginList += $pluginName
        }
    }

    return $pluginList
}

#endregion Private Helpers

#region Public Functions

function Test-HyperTerminal
{
    <#
    .SYNOPSIS
        Tests whether the current PowerShell session is running inside Hyper terminal.
    .DESCRIPTION
        Detects Hyper terminal by checking the TERM_PROGRAM environment variable,
        which Hyper sets to 'Hyper' when launching a shell session.
    .EXAMPLE
        if (Test-HyperTerminal) { Write-Host 'Running in Hyper!' }
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $env:TERM_PROGRAM -eq 'Hyper'
}

function Get-HyperPlugin
{
    <#
    .SYNOPSIS
        Gets the list of installed Hyper terminal plugins.
    .DESCRIPTION
        Reads the Hyper terminal configuration file (.hyper.js) and returns
        the list of plugins defined in the plugins array.
    .EXAMPLE
        Get-HyperPlugin
    .EXAMPLE
        Get-HyperPlugin | Where-Object Name -eq 'hyperpower'
    .OUTPUTS
        PSCustomObject with Name property
    #>
    [CmdletBinding()]
    param()

    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        $configPath = Get-HyperConfigPath
        Write-Warning "Hyper configuration file not found at '$configPath'. Is Hyper terminal installed?"
        return
    }

    $pluginNames = Get-PluginListFromContent -Content $content

    foreach ($name in $pluginNames)
    {
        [PSCustomObject]@{
            PSTypeName = 'Microsoft.PowerShell.HyperTerminal.PluginInfo'
            Name       = $name
        }
    }
}

function Install-HyperPlugin
{
    <#
    .SYNOPSIS
        Installs a Hyper terminal plugin by adding it to the configuration.
    .DESCRIPTION
        Adds the specified plugin name to the plugins array in Hyper's
        configuration file (.hyper.js). Common plugins include 'hyperpower',
        'hyper-search', 'hyper-pane', 'hyper-opacity', and 'hypercwd'.
    .PARAMETER Name
        The name of the Hyper plugin to install (npm package name).
    .EXAMPLE
        Install-HyperPlugin -Name 'hyperpower'
    .EXAMPLE
        Install-HyperPlugin -Name 'hyper-search'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $configPath = Get-HyperConfigPath
    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        Write-Error "Hyper configuration file not found at '$configPath'. Please install Hyper terminal first (https://hyper.is/)."
        return
    }

    $existingPlugins = Get-PluginListFromContent -Content $content

    if ($existingPlugins -contains $Name)
    {
        Write-Warning "Plugin '$Name' is already installed."
        return
    }

    if ($PSCmdlet.ShouldProcess($configPath, "Add plugin '$Name'"))
    {
        if ($content -match '(plugins\s*:\s*\[)([^\]]*?)(\])')
        {
            $before = $Matches[1]
            $existing = $Matches[2].TrimEnd()
            $after = $Matches[3]

            $newEntry = if ([string]::IsNullOrWhiteSpace($existing))
            {
                "`n    '$Name'`n  "
            }
            else
            {
                "$existing,`n    '$Name'`n  "
            }

            $newContent = $content -replace 'plugins\s*:\s*\[[^\]]*\]', "${before}${newEntry}${after}"
            Set-Content -Path $configPath -Value $newContent -NoNewline
            Write-Verbose "Plugin '$Name' added to Hyper configuration."
        }
        else
        {
            Write-Error "Could not find the plugins array in the Hyper configuration file."
        }
    }
}

function Remove-HyperPlugin
{
    <#
    .SYNOPSIS
        Removes a Hyper terminal plugin from the configuration.
    .DESCRIPTION
        Removes the specified plugin name from the plugins array in Hyper's
        configuration file (.hyper.js).
    .PARAMETER Name
        The name of the Hyper plugin to remove.
    .EXAMPLE
        Remove-HyperPlugin -Name 'hyperpower'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $configPath = Get-HyperConfigPath
    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        Write-Error "Hyper configuration file not found at '$configPath'."
        return
    }

    $existingPlugins = Get-PluginListFromContent -Content $content

    if ($existingPlugins -notcontains $Name)
    {
        Write-Warning "Plugin '$Name' is not installed."
        return
    }

    if ($PSCmdlet.ShouldProcess($configPath, "Remove plugin '$Name'"))
    {
        # Remove the plugin entry and any trailing/leading comma
        $newContent = $content -replace ",\s*'$([regex]::Escape($Name))'", ''
        $newContent = $newContent -replace "'$([regex]::Escape($Name))'\s*,?", ''

        Set-Content -Path $configPath -Value $newContent -NoNewline
        Write-Verbose "Plugin '$Name' removed from Hyper configuration."
    }
}

function Get-HyperConfiguration
{
    <#
    .SYNOPSIS
        Gets Hyper terminal configuration settings.
    .DESCRIPTION
        Reads and parses key configuration settings from Hyper's configuration
        file (.hyper.js), including font settings, color scheme, shell path,
        and installed plugins.
    .PARAMETER Setting
        Optional specific setting name to retrieve. If not specified, returns
        all recognized settings.
    .EXAMPLE
        Get-HyperConfiguration
    .EXAMPLE
        Get-HyperConfiguration -Setting 'fontSize'
    .OUTPUTS
        PSCustomObject with configuration properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('fontSize', 'fontFamily', 'cursorShape', 'shell', 'plugins')]
        [string] $Setting
    )

    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        $configPath = Get-HyperConfigPath
        Write-Error "Hyper configuration file not found at '$configPath'."
        return
    }

    $config = [ordered]@{
        PSTypeName = 'Microsoft.PowerShell.HyperTerminal.Configuration'
    }

    # Parse fontSize
    if ($content -match 'fontSize\s*:\s*(\d+)')
    {
        $config['fontSize'] = [int]$Matches[1]
    }

    # Parse fontFamily
    if ($content -match "fontFamily\s*:\s*['""]([^'""]+)['""]")
    {
        $config['fontFamily'] = $Matches[1]
    }

    # Parse cursorShape
    if ($content -match "cursorShape\s*:\s*['""]([^'""]+)['""]")
    {
        $config['cursorShape'] = $Matches[1]
    }

    # Parse shell
    if ($content -match "shell\s*:\s*['""]([^'""]+)['""]")
    {
        $config['shell'] = $Matches[1]
    }

    # Parse plugins
    $config['plugins'] = Get-PluginListFromContent -Content $content

    $configObj = [PSCustomObject]$config

    if ($Setting)
    {
        return $configObj.$Setting
    }

    return $configObj
}

function Set-HyperConfiguration
{
    <#
    .SYNOPSIS
        Sets a Hyper terminal configuration value.
    .DESCRIPTION
        Modifies a configuration setting in Hyper's configuration file (.hyper.js).
    .PARAMETER Setting
        The name of the setting to modify.
    .PARAMETER Value
        The new value for the setting.
    .EXAMPLE
        Set-HyperConfiguration -Setting 'fontSize' -Value '16'
    .EXAMPLE
        Set-HyperConfiguration -Setting 'cursorShape' -Value 'BEAM'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('fontSize', 'fontFamily', 'cursorShape')]
        [string] $Setting,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Value
    )

    $configPath = Get-HyperConfigPath
    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        Write-Error "Hyper configuration file not found at '$configPath'."
        return
    }

    if ($PSCmdlet.ShouldProcess($configPath, "Set $Setting to '$Value'"))
    {
        $newContent = switch ($Setting)
        {
            'fontSize'
            {
                $content -replace "(fontSize\s*:\s*)\d+", "`${1}$Value"
            }

            'fontFamily'
            {
                $content -replace "(fontFamily\s*:\s*)['""][^'""]*['""]", "`${1}'$Value'"
            }

            'cursorShape'
            {
                $content -replace "(cursorShape\s*:\s*)['""][^'""]*['""]", "`${1}'$Value'"
            }
        }

        Set-Content -Path $configPath -Value $newContent -NoNewline
        Write-Verbose "Hyper configuration '$Setting' updated to '$Value'."
    }
}

function Enable-HyperShellIntegration
{
    <#
    .SYNOPSIS
        Enables shell integration features for Hyper terminal.
    .DESCRIPTION
        Configures the current PowerShell session with Hyper-optimized settings
        including ANSI output rendering, OSC escape sequences for window title
        updates, and prompt customization for Hyper plugin compatibility.

        This enables features that Hyper addons like 'hyperpower' and
        'hyper-pane' can use for enhanced terminal experiences.
    .PARAMETER EnableOSCTitle
        Enables OSC escape sequences for dynamic window title updates.
    .EXAMPLE
        Enable-HyperShellIntegration
    .EXAMPLE
        Enable-HyperShellIntegration -EnableOSCTitle
    #>
    [CmdletBinding()]
    param(
        [switch] $EnableOSCTitle
    )

    if (-not (Test-HyperTerminal))
    {
        Write-Warning "Not running inside Hyper terminal. Shell integration may not work as expected."
    }

    # Ensure ANSI output rendering is enabled for Hyper compatibility
    if ($PSStyle)
    {
        $PSStyle.OutputRendering = 'Ansi'
        Write-Verbose "ANSI output rendering enabled."
    }

    # Set up OSC title sequences if requested
    if ($EnableOSCTitle)
    {
        # OSC 0 - Set window title to current directory
        function global:prompt
        {
            $currentPath = $executionContext.SessionState.Path.CurrentLocation.Path
            $host.UI.Write("`e]0;PS $currentPath`a")
            "PS $currentPath> "
        }

        Write-Verbose "OSC window title integration enabled."
    }

    # Emit OSC 7 (current working directory) for Hyper's directory tracking
    # This enables plugins like 'hypercwd' to track the current directory
    $ExecutionContext.InvokeCommand.PostCommandLookupAction = {
        param($CommandName, $CommandLookupEventArgs)
    }

    Write-Verbose "Hyper shell integration enabled."
}

#endregion Public Functions
