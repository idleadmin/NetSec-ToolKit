<#
.SYNOPSIS
Audits and uninstalls outdated per-user installations of Zoom across all local user profiles.

.DESCRIPTION
This script iterates through every non-special user profile on the system to locate Zoom instances installed in the Roaming AppData directory.

The script performs the following logic:

Identifies "Zoom.exe" and parses its product version, normalizing the version string to a three-part format for comparison.

Compares the discovered version against a hardcoded minimum threshold (6.2.0).

If the version is outdated, it forcibly terminates any running "Zoom" processes.

Triggers the Zoom uninstaller ("Installer.exe") located in the user profile using silent switches.

After a 5-second delay, it attempts to force-delete the residual Zoom binary folder to ensure a clean removal.

This script specifically targets the per-user (AppData) installation and does not affect the MSI-based machine-wide installation. Administrative privileges are required to query other user profiles and stop processes.

.OUTPUTS
Console output (Write-Host string messages indicating version detection, uninstallation progress, and folder cleanup status).

.EXAMPLE
Standard execution to audit all local user profiles and remove any Zoom installation older than version 6.2.0.

.\Uninstall-OldZoom.ps1

.EXAMPLE
Demonstrates the script's behavior on a profile with a compliant version. The script logs that the version is up-to-date and skips the removal logic for that user.

.\Uninstall-OldZoom.ps1
#>

# Define the Zoom uninstall path under user profiles
$zoomUninstallPath = "\AppData\Roaming\Zoom\uninstall\Installer.exe"

# Define the minimum version of Zoom that should be retained
$minZoomVersion = [Version]"6.2.0"

# Get all user profiles
$userProfiles = Get-WmiObject Win32_UserProfile | Where-Object { $_.Special -eq $false }

foreach ($profile in $userProfiles) {
    $zoomPath = Join-Path $profile.LocalPath $zoomUninstallPath
    $zoomExePath = Join-Path $profile.LocalPath "\AppData\Roaming\Zoom\bin\Zoom.exe"

    if (Test-Path $zoomExePath) {
        # Get the version of Zoom.exe
        $zoomVersion = (Get-Item $zoomExePath).VersionInfo.ProductVersion

        # Parse only the first three version components if more than 3
        $zoomVersionParts = $zoomVersion.Split(",")
        if ($zoomVersionParts.Count -ge 3) {
            $zoomVersionParsed = [Version]("$($zoomVersionParts[0]).$($zoomVersionParts[1]).$($zoomVersionParts[2])")
        } else {
            $zoomVersionParsed = [Version]$zoomVersion
        }

        Write-Host "Found Zoom version $zoomVersionParsed in profile: $($profile.LocalPath)"

        # Compare the Zoom version with the minimum version
        if ($zoomVersionParsed -lt $minZoomVersion) {
            # Close Zoom if it's running
            Get-Process -Name "Zoom" -ErrorAction SilentlyContinue | Stop-Process -Force
            
            # Uninstall Zoom using the Installer.exe silently
            if (Test-Path $zoomPath) {
                Write-Host "Zoom version is older than $minZoomVersion. Uninstalling..."
                $uninstallCommand = "& `"$zoomPath`" /uninstall /silent"
                Write-Host "Running uninstall command: $uninstallCommand"
                Invoke-Expression $uninstallCommand

                # Wait for a brief moment to allow uninstall to complete
                Start-Sleep -Seconds 5

                # Remove the Zoom folder
                $zoomRootFolder = [System.IO.Path]::GetDirectoryName($zoomExePath)
                Remove-Item -Path $zoomRootFolder -Recurse -Force -ErrorAction SilentlyContinue

                if (-not (Test-Path $zoomRootFolder)) {
                    Write-Host "Zoom folder removed from $($profile.LocalPath)"
                } else {
                    Write-Host "Failed to remove Zoom folder from $($profile.LocalPath)"
                }
            } else {
                Write-Host "Uninstall executable not found in profile: $($profile.LocalPath)"
            }
        } else {
            Write-Host "Zoom version is up-to-date. No action taken for profile: $($profile.LocalPath)"
        }
    } else {
        Write-Host "Zoom is not installed in profile: $($profile.LocalPath)"
    }
}

Write-Host "Zoom uninstall process completed."