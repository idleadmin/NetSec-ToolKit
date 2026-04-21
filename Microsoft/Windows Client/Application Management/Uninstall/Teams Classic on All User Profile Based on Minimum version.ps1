PowerShell
<#
.SYNOPSIS
Audits and removes outdated versions of Microsoft Teams (Classic) across all local user profiles.

.DESCRIPTION
This script scans all non-special user profiles on a system to identify installations of Microsoft Teams (Classic) located in the local AppData directory. For each profile found, it compares the file version of 'Teams.exe' against a specified minimum threshold (1.7.00.00000).

If an outdated version is detected, the script:

Terminates all active 'Teams' processes to prevent file locks.

Executes the native uninstaller command via the '--uninstall' flag.

Recursively force-deletes the Teams application folder in 'AppData\Local' to ensure a complete removal of residual files.

The script utilizes WMI to discover user profiles and requires administrative privileges to modify files across multiple user directories and terminate system processes.

.OUTPUTS
Console output (System.String) providing status updates, version details, and confirmation of removal actions for each scanned profile.

.EXAMPLE
Standard execution to audit all user profiles and remove Teams instances older than version 1.7.00.00000.

.\Remove-OldTeams.ps1

.EXAMPLE
Demonstrates the script's behavior when a profile is found with a compliant version. The script logs the version and skips the uninstallation/deletion logic for that specific user.

.\Remove-OldTeams.ps1
#>

# Define minimum version of Teams allowed
$minVersion = [version]"1.7.00.00000"  # Replace this with the minimum version of Teams.exe you want to allow

# Function to get the version of Teams.exe for a specific user profile
function Get-TeamsVersion {
    param (
        [string]$teamsExePath
    )
    
    if (Test-Path $teamsExePath) {
        $fileVersionInfo = (Get-Item $teamsExePath).VersionInfo
        return [version]$fileVersionInfo.ProductVersion
    } else {
        return $null
    }
}

# Function to uninstall Teams for a specific user profile
function Uninstall-Teams {
    param (
        [string]$teamsExePath
    )

    # Run Teams uninstaller silently
    $uninstallCommand = "$teamsExePath --uninstall"
    Write-Host "Running uninstall command: $uninstallCommand"
    Invoke-Expression $uninstallCommand
}

# Function to stop all Teams processes
function Stop-TeamsProcesses {
    Get-Process -Name Teams -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Host "Stopped all running Teams processes."
}

# Function to delete the Teams folder in a user profile
function Delete-TeamsFolder {
    param (
        [string]$teamsFolderPath
    )

    if (Test-Path $teamsFolderPath) {
        try {
            # Stop any running Teams processes
            Stop-TeamsProcesses

            # Try deleting the folder
            Remove-Item -Path $teamsFolderPath -Recurse -Force
            Write-Host "Deleted Teams folder: $teamsFolderPath"
        } catch {
            Write-Host "Failed to delete Teams folder: $teamsFolderPath. Error: $_"
        }
    }
}

# Main function to check all user profiles
function Process-UserProfiles {
    # Get all non-special user profiles on the system
    $userProfiles = Get-WmiObject Win32_UserProfile | Where-Object { $_.Special -eq $false }

    foreach ($profile in $userProfiles) {
        $teamsExePath = Join-Path $profile.LocalPath "AppData\Local\Microsoft\Teams\current\Teams.exe"
        $teamsFolderPath = Join-Path $profile.LocalPath "AppData\Local\Microsoft\Teams"

        $currentVersion = Get-TeamsVersion -teamsExePath $teamsExePath

        if ($currentVersion -ne $null) {
            Write-Host "Found Teams.exe version $currentVersion for user profile: $($profile.LocalPath)"
            
            # Check if the version is older than the minimum allowed version
            if ($currentVersion -lt $minVersion) {
                Write-Host "Teams.exe version $currentVersion is older than $minVersion. Uninstalling and deleting folder..."
                
                # Uninstall Teams and delete the Teams folder
                Uninstall-Teams -teamsExePath $teamsExePath
                Delete-TeamsFolder -teamsFolderPath $teamsFolderPath
            } else {
                Write-Host "Teams.exe version $currentVersion is up to date. No action needed for user profile: $($profile.LocalPath)"
            }
        } else {
            Write-Host "Teams.exe not found for user profile: $($profile.LocalPath)"
        }
    }
}

# Run the main function
Process-UserProfiles