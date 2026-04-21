<#
.SYNOPSIS
Performs a silent uninstallation of Palo Alto Networks GlobalProtect and cleans up residual registry entries.

.DESCRIPTION
This script automates the removal of the GlobalProtect agent by executing the following logic:

Identifies and stops the core GlobalProtect services ('PanGPS' and 'PanGPA') to prevent file locks.

Executes the MSI uninstaller ('msiexec.exe') using a specific Product GUID.

Applies silent switches (/qn) and disables automatic restarts (/norestart), while generating a verbose log file in the system TEMP directory.

Analyzes the uninstaller exit codes to provide context for success, missing installations (1605), or fatal errors (1603).

Performs a manual cleanup of the HKLM registry uninstall key if it persists after the MSI execution.

Manual GUID Retrieval Guide:
If the hardcoded GUID does not match your version, you can find the correct GUID manually using this PowerShell command:
Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall*" |
Get-ItemProperty | Where-Object { $_.DisplayName -like "GlobalProtect" } | Select-Object DisplayName, PSChildName

The 'PSChildName' returned (formatted as {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}) is the GUID required for the $globalProtectGUID variable.

.OUTPUTS
Console output (System.String) detailing the status of services, uninstallation progress, exit codes, and registry cleanup results.

.EXAMPLE
Standard execution to remove GlobalProtect from the local machine.

.\Uninstall-GlobalProtect.ps1

.EXAMPLE
Execution on a system where GlobalProtect is not installed. The script will attempt to stop services (finding none), trigger the MSI removal which returns exit code 1605, and confirm no registry keys remain.

.\Uninstall-GlobalProtect.ps1
#>

# Define the GlobalProtect application name and GUID
$globalProtectName = "GlobalProtect"
$globalProtectGUID = "{AC0DF8B0-6848-4441-A8D8-1F41B0D044F4}"
$uninstallCommand = "msiexec.exe /x $globalProtectGUID /qn /norestart"
$logFilePath = "$env:TEMP\globalprotect_uninstall_log.txt"

# Function to stop GlobalProtect services if running
function Stop-GlobalProtectServices {
    $serviceNames = @("PanGPS", "PanGPA")  # Common GlobalProtect services
    foreach ($service in $serviceNames) {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Write-Host "Stopping service: $service"
            Stop-Service -Name $service -Force
        }
    }
}

# Uninstallation process with detailed debug
try {
    # Step 1: Stop GlobalProtect services
    Write-Host "Attempting to stop GlobalProtect services..."
    Stop-GlobalProtectServices

    # Step 2: Execute uninstall command
    Write-Host "Starting uninstallation process with command: $uninstallCommand"
    $process = Start-Process -FilePath msiexec.exe -ArgumentList "/x", $globalProtectGUID, "/qn", "/norestart", "/L*V", $logFilePath -PassThru -Wait

    # Step 3: Check exit code and log result
    if ($process.ExitCode -eq 0) {
        Write-Host "GlobalProtect uninstallation completed successfully."
    } elseif ($process.ExitCode -eq 1603) {
        Write-Host "Uninstallation failed with exit code 1603. Ensure you have sufficient permissions or that the application is not currently in use."
    } elseif ($process.ExitCode -eq 1605) {
        Write-Host "GlobalProtect was not found for uninstallation. (Exit code 1605 indicates no action was taken.)"
    } else {
        Write-Host "GlobalProtect uninstallation failed with exit code: $($process.ExitCode)."
    }
} catch {
    Write-Host "An error occurred during the uninstallation process: $_"
}

# Step 4: Confirm registry cleanup if application still appears
$uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$globalProtectGUID"
if (Test-Path $uninstallKey) {
    try {
        Remove-Item -Path $uninstallKey -Recurse -Force
        Write-Host "Successfully cleaned up remaining registry entry for GlobalProtect at: $uninstallKey"
    } catch {
        Write-Host "Failed to remove registry entry: $_"
    }
} else {
    Write-Host "No remaining registry entry found for GlobalProtect."
}

# Final Step: Display uninstallation log location
if (Test-Path $logFilePath) {
    Write-Host "Uninstallation log can be found at: $logFilePath"
} else {
    Write-Host "No uninstallation log file found."
}