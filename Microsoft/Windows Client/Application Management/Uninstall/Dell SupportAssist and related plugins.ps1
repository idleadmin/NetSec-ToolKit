PowerShell
<#
.SYNOPSIS
Identifies and silently uninstalls Dell SupportAssist and its associated components from the local system.

.DESCRIPTION
This script automates the removal of "Dell SupportAssist" by performing a targeted search within the Windows Registry. It executes the following logic:

Searches both the 64-bit (HKLM:\SOFTWARE\Microsoft) and 32-bit (HKLM:\SOFTWARE\WOW6432Node) uninstall registry keys for entries where the DisplayName matches "Dell SupportAssist".

For every match found, it retrieves the 'UninstallString' property.

It analyzes the string to determine the installer type:

For MSI-based installers (msiexec), it appends '/quiet /norestart' for a silent, non-interactive removal.

For EXE-based installers, it appends '/S' as a default silent switch.

It ensures the command string is correctly quoted and executes it via cmd.exe, waiting for each uninstallation to complete before moving to the next component.

Note: This script requires Administrative privileges to access the HKLM registry hive and initiate system uninstalls.

.OUTPUTS
System.String (Console output messages documenting the search, formatting of uninstall strings, and execution status).


.EXAMPLE
Standard execution to remove Dell SupportAssist. The script identifies the main application and any related plugins in the registry and uninstalls them sequentially.

.\Uninstall-DellSupportAssist.ps1

.EXAMPLE
Demonstrates the script's behavior when Dell SupportAssist is not present on the system. It will report that no matching applications were found and exit gracefully.

.\Uninstall-DellSupportAssist.ps1
#>


# Uninstall Dell SupportAssist and related plugins using PowerShell
# Ensure the script runs with administrative privileges

# Define the application name to search
$appName = "Dell SupportAssist"
Write-Output "Searching for application: $appName and its related components"

# Function to get installed programs
Function Get-InstalledProgram {
    param (
        [string]$ProgramName
    )

    Write-Output "Searching for installed programs in registry paths..."

    # Check for 32-bit and 64-bit registry locations
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $programs = @()

    foreach ($path in $registryPaths) {
        Write-Output "Checking registry path: $path"
        $programs += Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*$ProgramName*"
        }
    }

    return $programs
}

# Find the applications
$apps = Get-InstalledProgram -ProgramName $appName

if ($apps -and $apps.Count -gt 0) {
    Write-Output "Found the following applications:"
    $apps | ForEach-Object { Write-Output " - $($_.DisplayName)" }

    foreach ($app in $apps) {
        $uninstallString = $app.UninstallString

        if ($uninstallString) {
            Write-Output "Uninstall string retrieved for $($app.DisplayName): $uninstallString"

            # Format the uninstall string based on its type
            if ($uninstallString -like "*msiexec*") {
                # Add silent switches for msiexec
                if ($uninstallString -notlike "*quiet*") {
                    $uninstallString += " /quiet /norestart"
                    Write-Output "Added silent switches to msiexec uninstall string."
                }
            } elseif ($uninstallString -like "*.exe*") {
                # Handle .exe uninstallers
                if ($uninstallString -notlike "*silent*" -and $uninstallString -notlike "*quiet*") {
                    $uninstallString += " /S"  # Default to /S for most .exe uninstallers
                    Write-Output "Added /S for silent execution of .exe uninstaller."
                }
            } else {
                Write-Output "Uninstall string format not recognized. Proceeding with the current command."
            }

            # Ensure the uninstall string is quoted if necessary
            if ($uninstallString -notmatch '^".*"$') {
                $uninstallString = "`"$uninstallString`""
                Write-Output "Enclosed uninstall string in quotes for proper execution."
            }

            # Execute the uninstall command
            Write-Output "Executing uninstall command for $($app.DisplayName)..."
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallString" -Wait -NoNewWindow
            Write-Output "Uninstallation process completed for $($app.DisplayName)."
        } else {
            Write-Output "Uninstall string not found for $($app.DisplayName). Please check the application manually."
        }
    }
} else {
    Write-Output "No applications found matching the name: $appName."
}

Write-Output "Script execution completed."