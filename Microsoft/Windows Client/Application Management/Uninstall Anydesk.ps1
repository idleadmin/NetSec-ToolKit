<#
.SYNOPSIS
Automates the termination, silent uninstallation, and deep cleanup of AnyDesk from the local system.

.DESCRIPTION
This script performs a comprehensive removal of AnyDesk by executing the following logic:

Identifies and forcibly terminates any active "AnyDesk" processes.

Locates the AnyDesk executable at the default path (C:\Program Files (x86)\AnyDesk\AnyDesk.exe) and triggers a silent removal using the --remove and --silent flags.

Recursively deletes residual application folders within Program Files (x86) and ProgramData.

Iterates through all local user profiles in C:\Users to purge AnyDesk configuration files from the Roaming AppData directory.

Conducts a recursive search across the entire C:\ drive to identify and remove any remaining AnyDesk executables.

Note: This script must be executed with Administrative privileges to modify system directories and terminate processes.

.OUTPUTS
Console output (System.String messages indicating progress, errors, and verbose file removal details).

.EXAMPLE
Standard execution to remove AnyDesk and all associated user data from the local machine.

.\Uninstall-AnyDesk.ps1

.EXAMPLE
Runs the script to clean up a system where AnyDesk might have been partially removed. The script will skip the uninstaller if the .exe is missing but will proceed with purging residual profile folders and stray executables.

.\Uninstall-AnyDesk.ps1
#>

# Run as Administrator!
Write-Output "Starting AnyDesk uninstallation..."

# Step 1: Terminate AnyDesk process if running
$processes = Get-Process -Name "AnyDesk" -ErrorAction SilentlyContinue
if ($processes) {
    Write-Output "AnyDesk process found. Terminating..."
    Stop-Process -Name "AnyDesk" -Force
    Start-Sleep -Seconds 3
}

# Step 2: Define the default installation path
$anyDeskPath = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"

# Step 3: Check if AnyDesk executable exists and attempt silent removal
if (Test-Path $anyDeskPath) {
    Write-Output "AnyDesk found at $anyDeskPath. Attempting silent removal..."
    try {
        Start-Process -FilePath $anyDeskPath -ArgumentList "--silent", "--remove" -Wait -NoNewWindow
        Write-Output "AnyDesk has been uninstalled silently."
    } catch {
        Write-Error "An error occurred during the silent removal: $_"
    }
} else {
    Write-Output "AnyDesk is not installed or not found at $anyDeskPath."
}

# Step 4: Clean up remaining files and folders
try {
    # Remove installation folder if it exists
    if (Test-Path "C:\Program Files (x86)\AnyDesk") {
        Remove-Item -Path "C:\Program Files (x86)\AnyDesk" -Recurse -Force -Verbose
    }
    # Remove ProgramData folder if it exists
    if (Test-Path "$env:ProgramData\AnyDesk") {
        Remove-Item -Path "$env:ProgramData\AnyDesk" -Recurse -Force -Verbose
    }
    # Remove AnyDesk folder from each user's AppData Roaming folder
    $users = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($user in $users) {
        $appDataPath = "C:\Users\$($user.Name)\AppData\Roaming\AnyDesk"
        if (Test-Path $appDataPath) {
            Remove-Item -Path $appDataPath -Recurse -Force -Verbose
        }
    }
    # Optionally remove any leftover AnyDesk executables from C: drive
    Get-ChildItem -Path C:\ -Recurse -Include AnyDesk*.exe -ErrorAction SilentlyContinue | Remove-Item -Force -Verbose
    Write-Output "Clean-up completed."
} catch {
    Write-Error "An error occurred during cleanup: $_"
}