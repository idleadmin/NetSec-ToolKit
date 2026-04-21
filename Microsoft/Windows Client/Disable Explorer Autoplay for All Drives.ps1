<#
.SYNOPSIS
Disables AutoPlay for all drives by setting the NoDriveTypeAutoRun registry value to 255.

.DESCRIPTION
This script manages the 'NoDriveTypeAutoRun' registry setting located in 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'. It ensures that the registry path exists before attempting to read or modify values.

The logic follows a three-step validation:

It checks if the registry key exists, creating it if necessary.

It evaluates the current value of 'NoDriveTypeAutoRun'. If the value is already set to 255 (0xFF), no action is taken.

If the value differs or does not exist, the script updates or creates it as a DWORD set to 255.

The script utilizes a global variable ($global:changesMade) to track modifications and provides detailed console feedback regarding the specific actions performed. Modification of the HKLM hive requires administrative privileges.

.OUTPUTS
Console output (Write-Host string messages confirming path creation, value updates, or state verification).
#>


# Define registry paths
$regPathMachine = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$settingName = "NoDriveTypeAutoRun"
$requiredValue = 255  # 0x000000FF to disable AutoPlay for all drives

# Variable to track whether changes were made
$global:changesMade = $false

# Function to ensure the registry path exists
function Ensure-RegistryPathExists {
    param (
        [string]$regPath
    )

    # Check if the path exists
    if (-not (Test-Path $regPath)) {
        # Create the registry path if it does not exist
        New-Item -Path $regPath -Force | Out-Null
        Write-Host "Registry path created: $regPath"
    }
}

# Function to check and update AutoPlay settings
function Update-AutoPlay {
    param (
        [string]$regPath,
        [string]$settingName,
        [int]$requiredValue
    )

    # Ensure the registry path exists
    Ensure-RegistryPathExists -regPath $regPath

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
        New-ItemProperty -Path $regPath -Name $settingName -Value $requiredValue -PropertyType DWord
        Write-Host "$settingName created and set to $requiredValue at $regPath"
        $global:changesMade = $true  # Set the flag indicating changes were made
    }
}

# Update AutoPlay settings for the machine
Update-AutoPlay -regPath $regPathMachine -settingName $settingName -requiredValue $requiredValue

# Check if any changes were made
if (-not $changesMade) {
    Write-Host "No changes were made to the AutoPlay settings."
} else {
    Write-Host "Changes were made to the AutoPlay settings."
}