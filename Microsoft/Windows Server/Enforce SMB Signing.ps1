PowerShell
<#
.SYNOPSIS
Enforces SMB packet signing requirements for both the SMB Client and SMB Server.

.DESCRIPTION
This script configures the Windows Registry to mandate SMB security signatures, enhancing network security against man-in-the-middle attacks. It targets the 'LanmanWorkstation' (Client) and 'LanmanServer' (Server) services by ensuring the 'EnableSecuritySignature' and 'RequireSecuritySignature' values are set to 1.

The script logic includes:

Verifying the existence of specific registry values within HKLM.

Updating or creating the values if they do not match the required state (1).

Monitoring changes through a global flag ($global:changesMade).

Forcing a restart of the 'LanmanWorkstation' and 'LanmanServer' services only if configuration changes were applied.

Note: This script requires elevated (Administrator) privileges to modify the registry and restart system services.

.OUTPUTS
Console output (Write-Host string messages indicating registry status, updates, and service restart confirmations).

.EXAMPLE
Standard execution to audit and enforce SMB signing. If the system is already compliant, no services are restarted.

.\Set-SMBSigning.ps1

.EXAMPLE
Execution on a system where SMB signing is disabled. The script will update the four registry values and then perform a forced restart of the LanmanWorkstation and LanmanServer services.

.\Set-SMBSigning.ps1
#>

# Define registry paths
$clientRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
$serverRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"

# Variable to track whether changes were made
$global:changesMade = $false

# Function to check and update SMB signing settings
function Update-SMBSigning {
    param (
        [string]$regPath,
        [string]$settingName,
        [int]$requiredValue
    )

    $currentValue = Get-ItemProperty -Path $regPath -Name $settingName -ErrorAction SilentlyContinue

    if ($currentValue -and $currentValue.$settingName -ne $null) {
        # If the value is already set to the required value, no need to change it
        if ($currentValue.$settingName -eq $requiredValue) {
            Write-Host "$settingName is already set to $requiredValue at $regPath. No changes needed."
        } else {
            # Value is not equal to the required value, so update it
            Set-ItemProperty -Path $regPath -Name $settingName -Value $requiredValue
            Write-Host "$settingName updated to $requiredValue at $regPath"
            $global:changesMade = $true  # Set the flag indicating changes were made
        }
    } else {
        # If the setting does not exist, create it
        New-ItemProperty -Path $regPath -Name $settingName -Value $requiredValue
        Write-Host "$settingName created and set to $requiredValue at $regPath"
        $global:changesMade = $true  # Set the flag indicating changes were made
    }
}

# Update SMB signing settings for the client
Update-SMBSigning -regPath $clientRegPath -settingName "EnableSecuritySignature" -requiredValue 1
Update-SMBSigning -regPath $clientRegPath -settingName "RequireSecuritySignature" -requiredValue 1

# Update SMB signing settings for the server
Update-SMBSigning -regPath $serverRegPath -settingName "EnableSecuritySignature" -requiredValue 1
Update-SMBSigning -regPath $serverRegPath -settingName "RequireSecuritySignature" -requiredValue 1

# Check if any changes were made
if (-not $changesMade) {
    Write-Host "No changes were made to the SMB signing settings."
} else {
    # Restart services if changes were made
    Restart-Service -Name "LanmanWorkstation" -force
    Restart-Service -Name "LanmanServer" -force
    Write-Host "LanmanWorkstation and LanmanServer services have been restarted."
}