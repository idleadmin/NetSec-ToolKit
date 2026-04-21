<#
.SYNOPSIS
Disables the SMBv1 protocol across the Windows Optional Feature, Server configuration, and Client configuration.

.DESCRIPTION
This script implements a multi-layered approach to decommission the insecure SMBv1 protocol on a Windows system.

It disables the 'SMB1Protocol' Windows Optional Feature using the Deployment Image Servicing and Management (DISM) cmdlets with the -NoRestart flag.

It modifies the SMB Server configuration to explicitly disable SMBv1 protocol support.

It audits the SMB Client capabilities. If the 'Set-SmbClientConfiguration' cmdlet supports the 'EnableSMB1Protocol' parameter, it uses it to disable the client-side protocol.

If the cmdlet parameter is unsupported (common in older Windows versions), the script performs a fallback registry modification by setting the 'SMB1' value to 0 in the LanmanWorkstation parameters.

Note: This script must be run with Administrative privileges. A system restart is required to fully commit the changes to the network stack.

.OUTPUTS
Console output (System.String messages confirming the status of each step or warnings if specific methods are unsupported or fail).

.EXAMPLE
Standard execution to disable SMBv1 on the local machine using default settings.

.\Disable-SMBv1.ps1

.EXAMPLE
Runs the script on a legacy system where the SMB Client cmdlet is outdated. The script will detect the missing parameter and automatically use the registry fallback method.

.\Disable-SMBv1.ps1
#>


# Run as Administrator!

Write-Output "Disabling SMBv1..."



# Step 1: Remove SMBv1 Windows Optional Feature

Write-Output "Disabling SMBv1 Windows Optional Feature..."

Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue



# Step 2: Disable SMBv1 on the server side

try {

    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue

    Write-Output "SMBv1 disabled on the server."

} catch {

    Write-Warning "Failed to disable SMBv1 on the server: $_"

}



# Step 3: Disable SMBv1 on the client side

# First, check if the Set-SmbClientConfiguration cmdlet supports the parameter.

$clientCmd = Get-Command Set-SmbClientConfiguration -ErrorAction SilentlyContinue

$paramExists = $false

if ($clientCmd) {

    $params = $clientCmd.Parameters.Keys

    if ($params -contains "EnableSMB1Protocol") {

        $paramExists = $true

    }

}



if ($paramExists) {

    try {

        Set-SmbClientConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue

        Write-Output "SMBv1 disabled on the client using Set-SmbClientConfiguration."

    } catch {

        Write-Warning "Failed to disable SMBv1 on the client via cmdlet: $_"

    }

} else {

    Write-Warning "Set-SmbClientConfiguration does not support the EnableSMB1Protocol parameter. Using registry update instead."

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"

    if (Test-Path $regPath) {

        try {

            Set-ItemProperty -Path $regPath -Name "SMB1" -Value 0 -Force

            Write-Output "SMBv1 disabled on the client via registry."

        } catch {

            Write-Warning "Failed to update registry for SMBv1 client: $_"

        }

    } else {

        Write-Warning "Registry path not found: $regPath"

    }

}



Write-Output "SMBv1 has been disabled. A system restart is recommended for all changes to take effect."