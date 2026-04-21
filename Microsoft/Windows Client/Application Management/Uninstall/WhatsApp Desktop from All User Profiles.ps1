PowerShell
<#
.SYNOPSIS
Identifies and removes all WhatsApp-related Appx packages for all users with a built-in execution timeout.

.DESCRIPTION
This script executes a script block as a background job to locate and uninstall WhatsApp Desktop and WhatsApp Beta packages.

The removal logic involves:

Querying the system for all Appx packages where the Name or PackageFullName matches the "WhatsApp" string.

Attempting to remove each identified package for all users using the 'Remove-AppxPackage' cmdlet with the '-AllUsers' switch.

Implementing a 300-second (5-minute) timeout via 'Wait-Job'. If the uninstallation process exceeds this duration, the job is forcibly stopped and removed to prevent hung processes.

The script provides real-time feedback on package discovery and the success or failure of each uninstallation attempt. Administrative privileges are required to remove packages for all users.

.OUTPUTS
Console output (System.String) indicating found packages, uninstallation results, or timeout notifications.

.EXAMPLE
Standard execution to remove all WhatsApp Appx packages from the system for all users.

.\Uninstall-WhatsAppAppx.ps1

.EXAMPLE
Demonstrates the script's behavior when no packages are found. The background job will complete quickly and report that no packages were identified.

.\Uninstall-WhatsAppAppx.ps1
#>

$scriptBlock = {
    $found = $false

    # Grab all WhatsApp-related packages (regular and beta)
    $packages = Get-AppxPackage -AllUsers | Where-Object {
        $_.Name -like "*WhatsApp*" -or $_.PackageFullName -like "*WhatsApp*"
    }

    if ($packages) {
        foreach ($pkg in $packages) {
            Write-Output "Found package: $($pkg.PackageFullName)"
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Write-Output "Successfully uninstalled: $($pkg.PackageFullName)"
                $found = $true
            } catch {
                Write-Output "Failed to uninstall $($pkg.PackageFullName): $_"
            }
        }
    }

    if (-not $found) {
        Write-Output "No WhatsApp packages found. Nothing to uninstall."
    }
}

# Run with 5-minute timeout
$job = Start-Job -ScriptBlock $scriptBlock
if (Wait-Job -Job $job -Timeout 300) {
    Receive-Job -Job $job
} else {
    Write-Output "Script timed out after 5 minutes. Stopping job."
    Stop-Job -Job $job
    Remove-Job -Job $job
}