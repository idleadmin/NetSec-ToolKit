<#
.SYNOPSIS
Configures LSA registry settings to restrict anonymous access to the system.

.DESCRIPTION
This script iterates through a predefined array of registry keys within 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' to enforce security best practices regarding anonymous connections. It specifically targets 'EveryoneIncludesAnonymous', 'RestrictAnonymous', and 'RestrictAnonymousSAM'.

For each key, the script:

Checks if the value currently exists and matches the desired state.

If the value is already correct, it skips the update to minimize registry writes.

If the value is missing or incorrect, it uses Set-ItemProperty with the -Force parameter to create or update the entry.

The script tracks the overall status and provides a final summary indicating whether the system was already compliant or if updates were applied. Administrative privileges are required for execution.

.OUTPUTS
Console output (Write-Host string messages detailing the status of each registry key and a final execution summary).
#>

# Define the registry keys and their desired values
$registryKeys = @(
    @{
        Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa";
        Name  = "EveryoneIncludesAnonymous";
        Value = 0
    },
    @{
        Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa";
        Name  = "RestrictAnonymous";
        Value = 1
    },
    @{
        Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa";
        Name  = "RestrictAnonymousSAM";
        Value = 1
    }
)

# Function to check and set registry values
function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        [int]$Value
    )
    $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Name -ErrorAction SilentlyContinue
    if ($currentValue -eq $Value) {
        Write-Host "$Name is already set to $Value at $Path. No changes needed."
        return $true
    } elseif ($null -eq $currentValue) {
        Write-Host "$Name does not exist at $Path. Creating and setting to $Value."
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force
    } else {
        Write-Host "$Name has an incorrect value at $Path. Updating to $Value."
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force
    }
    return $false
}

# Check and update registry values
$allCorrect = $true
foreach ($key in $registryKeys) {
    $result = Set-RegistryValue -Path $key.Path -Name $key.Name -Value $key.Value
    if (-not $result) {
        $allCorrect = $false
    }
}

# End script if all values were correct
if ($allCorrect) {
    Write-Host "All registry values are already set correctly. No changes made."
} else {
    Write-Host "Registry values have been updated where necessary."
}

Write-Host "Script execution complete."