<#
.SYNOPSIS
Terminates any active TeamViewer processes and executes a silent uninstallation using known file system paths.

.DESCRIPTION
This script automates the removal of TeamViewer by performing two primary actions:

It checks for any running processes named "TeamViewer". If found, it forcibly terminates them using Stop-Process to ensure the uninstaller can modify or delete files without locks.

It searches for the "uninstall.exe" utility in standard 64-bit and 32-bit Program Files directories.

Upon locating a valid uninstaller path, it triggers the uninstaller with the "/S" argument for a silent, non-interactive execution and waits for the process to complete before proceeding.

The script provides real-time console feedback throughout the execution. Administrative privileges are required to stop system processes and execute uninstallers in protected directories.

.OUTPUTS
Console output (System.String) describing process termination status and uninstallation progress.

.EXAMPLE
Standard execution to terminate and uninstall TeamViewer using default installation paths.

.\Uninstall-TeamViewer.ps1

.EXAMPLE
Execution on a system where TeamViewer is installed in the x86 directory. The script will skip the 64-bit path check, find the x86 uninstaller, and execute the silent removal.

.\Uninstall-TeamViewer.ps1
#>

# Define the name of the TeamViewer process
$processName = "TeamViewer"

# Define possible uninstaller paths
$uninstallerPaths = @(
    "C:\Program Files\TeamViewer\uninstall.exe",
    "C:\Program Files (x86)\TeamViewer\uninstall.exe"
)

# Step 1: Terminate the TeamViewer process if running
$teamViewerProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue
if ($teamViewerProcess) {
    Write-Host "TeamViewer process found. Terminating..."
    Stop-Process -Name $processName -Force
    Write-Host "TeamViewer process has been terminated."
} else {
    Write-Host "TeamViewer process not running."
}

# Step 2: Uninstall TeamViewer by checking both possible paths
$uninstallerFound = $false
foreach ($path in $uninstallerPaths) {
    if (Test-Path $path) {
        Write-Host "TeamViewer uninstaller found at: $path"
        Write-Host "Uninstalling TeamViewer..."
        Start-Process -FilePath $path -ArgumentList "/S" -Wait
        Write-Host "TeamViewer has been uninstalled from: $path"
        $uninstallerFound = $true
        break  # Exit the loop once the uninstaller is found and executed
    }
}

if (-not $uninstallerFound) {
    Write-Host "TeamViewer uninstaller could not be found in any of the expected paths."
}