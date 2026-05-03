<#
.SYNOPSIS
Uninstalls .NET Desktop Runtime versions older than 8.0, provided a 8.0+ version is already installed.

.DESCRIPTION
This script performs a cleanup of legacy .NET Desktop Runtimes to maintain system hygiene. It first ensures the session is running with Administrative privileges and verifies that .NET Desktop Runtime 8.0 or higher is present on the system as a safeguard. It then scans the Windows Registry (both 64-bit and 32-bit HKLM nodes) for installed applications matching "Desktop Runtime" or "WindowsDesktop.App". For any discovered version strictly less than 8.0, the script attempts a silent uninstallation. It prioritizes MSI-based uninstallation via GUIDs but includes a fallback mechanism that cycles through common executable silent switches (/quiet, /silent, /S).

.OUTPUTS
Console output (Write-Host) indicating the status of discovery, version checks, and uninstallation success or failure.

.EXAMPLE
.\Remove-OldNetRuntimes.ps1

Standard execution. The script checks for admin rights, verifies .NET 8.0+ exists, and removes older versions silently.
#>

# --- helper: ensure elevated (simple check) ---
function Ensure-Elevated {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "This script must be run elevated. Please restart PowerShell as Administrator."
        exit 1
    }
}

# --- parse dotnet runtimes and check for Desktop runtime >= 8.0 ---
function Has-DesktopRuntime8Plus {
    $dotnetExe = (Get-Command dotnet -ErrorAction SilentlyContinue).Path
    if (-not $dotnetExe) {
        Write-Host "dotnet CLI not found. Please ensure .NET is installed."
        return $false
    }
    $lines = & $dotnetExe --list-runtimes 2>$null
    if (-not $lines) { return $false }
    foreach ($line in $lines) {
        if ($line -match 'Microsoft\.WindowsDesktop\.App\s+([0-9]+\.[0-9]+\.[0-9]+)') {
            try {
                $v = [Version]$matches[1]
                if ($v -ge [Version]"8.0.0") {
                    return $true
                }
            } catch { }
        }
    }
    return $false
}

# --- attempt uninstall of MSI using GUID or MSI token in the uninstallstring ---
function Uninstall-MsiFromString {
    param([string]$uninstallString, [string]$displayName)
    if (-not $uninstallString) { return $false }

    # Extract GUID if present
    $guidMatch = [regex]::Match($uninstallString, '\{[0-9A-Fa-f\-]{36}\}')
    if ($guidMatch.Success) {
        $guid = $guidMatch.Value
        Write-Host " -> Using product GUID $guid to uninstall $displayName"
        $args = "/x", $guid, "/qn", "/norestart"
        $p = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
        if ($p -and $p.ExitCode -eq 0) {
            Write-Host "    Uninstall succeeded (ExitCode 0)."
            return $true
        } else {
            Write-Host "    msiexec returned exit code $($p.ExitCode) (or failed to start)."
            return $false
        }
    }

    # If no GUID, try to replace /I with /X in the string (common registry quirk)
    if ($uninstallString -match 'msi(exec)?\.exe' -and $uninstallString -match '/I' ) {
        $new = $uninstallString -replace '/I', '/X'
        if ($new -notmatch '/qn') { $new += ' /qn /norestart' }
        Write-Host " -> Running adjusted MSI command: $new"
        # run via cmd /c to let the command string parse as the registry stored one
        $rc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $new -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
        return ($rc -and $rc.ExitCode -eq 0)
    }

    return $false
}

# --- attempt uninstall of an exe using common silent switches ---
function Uninstall-ExeWithSilentSwitches {
    param([string]$uninstallString, [string]$displayName)

    # split path and args
    $exePath = $uninstallString
    $exeArgs = ""
    if ($uninstallString -match '^(\"[^\"]+\"|\S+)\s*(.*)$') {
        $exePath = $Matches[1].Trim('"')
        $exeArgs = $Matches[2].Trim()
    }

    if (-not (Test-Path $exePath)) {
        # maybe the uninstallstring is like: rundll32.exe setupapi,InstallHinfSection ... or similar; try raw execution fallback
        Write-Host " -> Uninstall path '$exePath' not found on disk. Trying raw command execution of stored uninstall string..."
        try {
            $rc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $uninstallString -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
            return ($rc -and $rc.ExitCode -eq 0)
        } catch { return $false }
    }

    $attempts = @(
        { param($p,$a) Start-Process -FilePath $p -ArgumentList ($a + " /quiet /norestart") -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue },
        { param($p,$a) Start-Process -FilePath $p -ArgumentList ($a + " /quiet") -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue },
        { param($p,$a) Start-Process -FilePath $p -ArgumentList ($a + " /silent") -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue },
        { param($p,$a) Start-Process -FilePath $p -ArgumentList ($a + " /S") -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue }
    )

    foreach ($fn in $attempts) {
        try {
            Write-Host " -> Trying: `"$exePath`" $exeArgs + common silent switches"
            $p = & $fn $exePath $exeArgs
            if ($p -and $p.ExitCode -eq 0) {
                Write-Host "    Uninstall succeeded (ExitCode 0)."
                return $true
            } else {
                Write-Host "    Attempt exit code: $($p.ExitCode)"
            }
        } catch {
            Write-Host "    Attempt failed: $($_.Exception.Message)"
        }
    }

    return $false
}

# --- main ---
Ensure-Elevated

if (-not (Has-DesktopRuntime8Plus)) {
    Write-Host "No .NET Desktop Runtime 8.0 or above found. Aborting uninstallation."
    exit 0
}
Write-Host "Found .NET Desktop Runtime version 8.0 or above. Proceeding to uninstall older versions..."

$uninstallRoots = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$found = $false
foreach ($root in $uninstallRoots) {
    Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty -Path $_.PsPath -ErrorAction SilentlyContinue
        if (-not $props) { return }
        if (-not $props.DisplayName) { return }

        # Filter for Desktop runtimes - be permissive
        if ($props.DisplayName -match 'Desktop Runtime' -or $props.DisplayName -match 'WindowsDesktop\.App' -or $props.DisplayName -match 'Microsoft.*Desktop Runtime') {
            $disp = $props.DisplayName
            $verText = $props.DisplayVersion
            try {
                $ver = if ($verText) { [Version]$verText } else { $null }
            } catch { $ver = $null }

            if ($ver -and $ver -lt [Version]"8.0") {
                $found = $true
                Write-Host "Uninstall target found: $disp  Version: $verText"
                $uninstallString = $props.UninstallString

                if (-not $uninstallString) {
                    Write-Host " -> No UninstallString in registry; skipping."
                    return
                }

                # Prefer MSI approach when possible
                $ok = $false
                if ($uninstallString -match 'msi(exec)?\.exe' -or $uninstallString -match '\{[0-9A-Fa-f\-]{36}\}') {
                    $ok = Uninstall-MsiFromString -uninstallString $uninstallString -displayName $disp
                }

                if (-not $ok) {
                    # Try exe silent switches fallback
                    $ok = Uninstall-ExeWithSilentSwitches -uninstallString $uninstallString -displayName $disp
                }

                if (-not $ok) {
                    Write-Host " -> Failed to silently uninstall $disp. You may need to run the uninstall manually or examine the UninstallString: $uninstallString"
                }
            }
        }
    }
}

if (-not $found) {
    Write-Host "No installed .NET Desktop Runtime older than 8.0 was found to uninstall."
} else {
    Write-Host "Completed attempts to uninstall older runtimes."
}
