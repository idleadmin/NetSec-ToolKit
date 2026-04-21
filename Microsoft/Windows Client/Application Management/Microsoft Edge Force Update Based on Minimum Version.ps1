<#
.SYNOPSIS
Checks the installed version of Microsoft Edge and forces a silent update if it falls below a specified version threshold.

.DESCRIPTION
This script audits the local installation of Microsoft Edge by inspecting the 'msedge.exe' binary metadata. It performs the following logic:

Compares the current product version against a hardcoded minimum version (133.0.0.0).

If the version is outdated, it forcibly terminates all running 'msedge' processes to allow file updates.

Locates the 'MicrosoftEdgeUpdate.exe' utility within the Program Files (x86) directory.

Triggers a silent installation command using the specific Application GUID for Microsoft Edge.

Pauses for 30 seconds to allow the update process to finalize, then re-verifies the installed version to confirm success.

Note: This script requires Administrative privileges to terminate processes and execute the Edge Update utility with elevated permissions.

.OUTPUTS
Console output (Write-Host and Write-Warning messages indicating version status, update exit codes, and post-update verification results).

.EXAMPLE
Standard execution to audit and potentially update Microsoft Edge to meet the version 133.0.0.0 requirement.

.\Update-Edge.ps1

.EXAMPLE
Demonstrates the script's behavior when Edge is already compliant. The script logs the current version and exits without terminating processes or triggering the updater.

.\Update-Edge.ps1
#>

# Define the minimum allowed version of Edge (adjust as needed)
$minEdgeVersion = [version]"133.0.0.0"
$edgeExePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

# Function to stop Edge processes
function Stop-EdgeProcesses {
    Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Host "Stopped all running Edge processes."
}

if (Test-Path $edgeExePath) {
    $currentVersion = [version]((Get-Item $edgeExePath).VersionInfo.ProductVersion)
    Write-Host "Installed Edge version: $currentVersion"

    if ($currentVersion -lt $minEdgeVersion) {
        Write-Host "Edge version is outdated. Forcing update..."

        # Stop any running Edge processes
        Stop-EdgeProcesses

        # Get the Edge update executable using the found approach
        $edgeUpdater = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" -ErrorAction SilentlyContinue
        if ($edgeUpdater) {
            $arguments = "/silent /install appguid={56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}&appname=Microsoft%20Edge&needsadmin=True"
            $exitCode = (Start-Process -FilePath $edgeUpdater.FullName -ArgumentList $arguments -NoNewWindow -PassThru -Wait).ExitCode
            Write-Host "Edge updater exit code: $exitCode"
            
            Write-Host "Waiting 30 seconds for update to take effect..."
            Start-Sleep -Seconds 30
            
            $newVersion = [version]((Get-Item $edgeExePath).VersionInfo.ProductVersion)
            Write-Host "New installed Edge version: $newVersion"
            
            if ($newVersion -ge $minEdgeVersion) {
                Write-Host "Edge successfully updated."
            }
            else {
                Write-Warning "Edge update did not succeed immediately. A system restart may be required, or check update logs at %ProgramData%\Microsoft\EdgeUpdate\."
            }
        }
        else {
            Write-Warning "Edge update executable not found."
        }
    }
    else {
        Write-Host "Edge is up to date."
    }
}
else {
    Write-Host "Microsoft Edge executable not found at $edgeExePath."
}

Write-Host "Script completed. Please restart the system to allow any pending updates to take effect."