<#
.SYNOPSIS
Audits and uninstalls outdated user-level Google Chrome installations across all local user profiles.

.DESCRIPTION
This script iterates through every non-special user profile on the system to locate Google Chrome instances installed in the AppData directory. It performs the following logic:

Identifies the highest installed Chrome version within a profile by inspecting 'chrome.dll' metadata.

Compares the detected version against a hardcoded minimum threshold (134.0.6998.117).

If the version is below the threshold, it attempts a silent uninstallation using the Chrome 'setup.exe' utility found in the user's 'Installer' directory.

If the uninstaller is missing or fails to execute, the script force-deletes the Chrome application folder to ensure the outdated version is removed.

This script is specifically designed for environments where Chrome was installed per-user rather than per-machine. It requires administrative privileges to query user profiles and modify files across the filesystem.

.OUTPUTS
Console output (Write-Host and Write-Warning messages indicating version detection results, uninstallation status, and file system modifications).

.EXAMPLE
Standard execution to find and remove outdated Chrome installations for all local users.

.\Remove-OldChrome.ps1

.EXAMPLE
Demonstrates script behavior when a profile contains a version equal to or higher than the threshold. The script logs the version and skips uninstallation for that specific profile.

.\Remove-OldChrome.ps1
#>

# Define the minimum allowed version of Chrome
$minVersion = [version]"134.0.6998.117"

# Function to search for a version folder containing chrome.dll
function Get-ChromeVersionAndPath {
    param(
        [string]$appFolder
    )
    $versionFolders = Get-ChildItem -Path $appFolder -Directory -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -match '^\d+(\.\d+)+$' }
    $results = @()
    foreach ($folder in $versionFolders) {
         $chromeDll = Join-Path $folder.FullName "chrome.dll"
         if (Test-Path $chromeDll) {
              $fileVersion = (Get-Item $chromeDll).VersionInfo.ProductVersion
              $version = [version]$fileVersion
              $results += [PSCustomObject]@{
                  Version = $version
                  FilePath = $chromeDll
                  Folder   = $folder.FullName
              }
         }
    }
    if ($results.Count -gt 0) {
         # Return the folder with the highest version
         return $results | Sort-Object Version -Descending | Select-Object -First 1
    }
    return $null
}

# Function to uninstall Google Chrome using the installer
function Uninstall-Chrome {
    param(
         [string]$chromeUninstallPath
    )
    if (Test-Path $chromeUninstallPath) {
         Write-Host "Running uninstall command for Chrome: $chromeUninstallPath"
         # Execute uninstaller silently
         Start-Process -FilePath $chromeUninstallPath -ArgumentList "/silent", "/uninstall" -NoNewWindow -Wait
         Start-Sleep -Seconds 5  # Allow time for uninstallation to complete
         return $true
    } else {
         Write-Warning "Chrome uninstaller not found: $chromeUninstallPath"
         return $false
    }
}

# Function to delete the Chrome application folder
function Delete-ChromeFolder {
    param(
         [string]$chromeFolderPath
    )
    if (Test-Path $chromeFolderPath) {
         try {
              Remove-Item -Path $chromeFolderPath -Recurse -Force
              Write-Host "Deleted Chrome folder: $chromeFolderPath"
         } catch {
              Write-Warning "Failed to delete Chrome folder: $chromeFolderPath. Error: $_"
         }
    }
}

# Main function to process all non-special user profiles
function Process-UserProfiles {
    $userProfiles = Get-WmiObject Win32_UserProfile | Where-Object { $_.Special -eq $false }
    foreach ($profile in $userProfiles) {
         $chromeAppFolder = Join-Path $profile.LocalPath "AppData\Local\Google\Chrome\Application"
         if (Test-Path $chromeAppFolder) {
              $chromeInfo = Get-ChromeVersionAndPath -appFolder $chromeAppFolder
              if ($chromeInfo -ne $null) {
                   Write-Host "Found Chrome version $($chromeInfo.Version) at $($chromeInfo.Folder) for profile: $($profile.LocalPath)"
                   if ($chromeInfo.Version -lt $minVersion) {
                         Write-Host "Chrome version $($chromeInfo.Version) is older than $minVersion. Uninstalling..."
                         
                         # Define the expected path for the uninstaller
                         $chromeUninstallPath = Join-Path $profile.LocalPath "AppData\Local\Google\Chrome\Application\Installer\setup.exe"
                         
                         # Attempt uninstallation
                         $uninstallSuccess = Uninstall-Chrome -chromeUninstallPath $chromeUninstallPath
                         
                         # If uninstaller is not found or uninstall fails, proceed with folder deletion
                         if (-not $uninstallSuccess) {
                              Write-Warning "Uninstaller not found or uninstallation failed. Proceeding to delete the Chrome folder."
                         }
                         Delete-ChromeFolder -chromeFolderPath $chromeAppFolder
                   } else {
                         Write-Host "Chrome version $($chromeInfo.Version) is up to date. No action needed for profile: $($profile.LocalPath)"
                   }
              } else {
                   Write-Host "Chrome not found for user profile: $($profile.LocalPath)"
              }
         } else {
              Write-Host "Chrome application folder not found for user profile: $($profile.LocalPath)"
         }
    }
}

# Run the main function
Process-UserProfiles