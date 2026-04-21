<#
.SYNOPSIS
Sets the Windows CachedLogonsCount registry value to 0 to disable cached domain credentials.

.DESCRIPTION
This script checks the 'CachedLogonsCount' registry value under 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'.
If the value is already set to 0, the script outputs a status message and exits without making changes.
If the value exists but is not 0, it updates the value to 0.
If the registry value does not exist entirely, it creates the property as a String type and sets it to 0.
This action effectively prevents Windows from caching domain logons. Note: This script must be run in an elevated PowerShell session (Run as Administrator) to successfully modify the HKLM hive.

.OUTPUTS
Console output (Write-Host string messages indicating the status or action taken).
#>

# Define the registry path
$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Check if the CachedLogonsCount value exists
$cachedLogonsCount = Get-ItemProperty -Path $regPath -Name CachedLogonsCount -ErrorAction SilentlyContinue

if ($cachedLogonsCount) {
    # If CachedLogonsCount is already 0, stop the script
    if ($cachedLogonsCount.CachedLogonsCount -eq "0") {
        Write-Host "CachedLogonsCount is already set to 0. No changes needed."
        exit
    } else {
        # Update the CachedLogonsCount value to 0
        Set-ItemProperty -Path $regPath -Name CachedLogonsCount -Value "0"
        Write-Host "CachedLogonsCount value updated to 0."
    }
} else {
    # Create the CachedLogonsCount entry and set it to 0
    New-ItemProperty -Path $regPath -Name CachedLogonsCount -Value "0" -PropertyType String
    Write-Host "CachedLogonsCount value created and set to 0."
}