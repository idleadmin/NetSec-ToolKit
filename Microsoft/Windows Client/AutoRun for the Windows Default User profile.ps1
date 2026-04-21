<#
.SYNOPSIS
Disables AutoPlay/AutoRun for the Windows Default User profile (HKU.DEFAULT).

.DESCRIPTION
This script targets the 'NoDriveTypeAutoRun' registry setting for the Default User hive to ensure that AutoPlay is disabled for all new user profiles created on the system.

The script performs the following logic:

Validates the existence of the registry path 'HKU.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', creating it if it is missing.

Queries the current value of 'NoDriveTypeAutoRun'.

If the value is already set to 255 (0xFF), it reports that no changes are needed.

If the value is incorrect or missing, it utilizes the external 'reg.exe' utility via 'Invoke-Expression' to force-apply the REG_DWORD value of 255.

This approach ensures that baseline security policies regarding removable media are applied to the default profile. Administrative privileges are required to modify the HKU hive.

.OUTPUTS
Console output (Write-Host messages indicating registry path status and value updates).

.EXAMPLE
Standard execution to ensure the Default User profile has AutoPlay disabled.

.\Disable-DefaultUserAutoPlay.ps1

.EXAMPLE
Demonstrates the script's behavior when the registry path does not yet exist. The script will create the necessary key structure before using reg.exe to set the value.

.\Disable-DefaultUserAutoPlay.ps1
#>

# Define registry path for Default User in HKU
$regPathDefaultUser = "HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$settingName = "NoDriveTypeAutoRun"
$requiredValue = 255  # 0x000000FF to disable AutoPlay for all drives

# Function to update AutoPlay setting using PowerShell and reg.exe
function Update-AutoPlayWithReg {
    param (
        [string]$regPath,
        [string]$settingName,
        [int]$requiredValue
    )

    # Check if the registry path exists
    if (!(Test-Path "Registry::$regPath")) {
        # Create the registry path if it doesn't exist
        New-Item -Path "Registry::$regPath" -Force | Out-Null
        Write-Host "Registry path $regPath created."
    }

    # Check if the registry value exists
    $currentValue = (Get-ItemProperty -Path "Registry::$regPath" -Name $settingName -ErrorAction SilentlyContinue).$settingName

    if ($currentValue -ne $null) {
        # If the value is already set to the required value, no need to change it
        if ($currentValue -eq $requiredValue) {
            Write-Host "$settingName is already set to $requiredValue at $regPath. No changes needed."
        } else {
            # Value is not equal to the required value, so update it
            Invoke-Expression "reg add `"$regPath`" /v $settingName /t REG_DWORD /d $requiredValue /f"
            Write-Host "$settingName updated to $requiredValue at $regPath"
        }
    } else {
        # If the setting does not exist, create it
        Invoke-Expression "reg add `"$regPath`" /v $settingName /t REG_DWORD /d $requiredValue /f"
        Write-Host "$settingName created and set to $requiredValue at $regPath"
    }
}

# Update AutoPlay settings for the Default User using reg.exe
Update-AutoPlayWithReg -regPath $regPathDefaultUser -settingName $settingName -requiredValue $requiredValue