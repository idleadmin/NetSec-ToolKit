<#
.SYNOPSIS
  Renames the local built-in Guest user account to "rambo".

.DESCRIPTION
  This script checks for the existence of a local user account named "Guest" on the system. If the account is found, it utilizes the Rename-LocalUser cmdlet to change its name to "mehmon". The script provides console feedback via Write-Host indicating whether the rename operation was successful. If the target account could not be found—implying it does not exist or has already been renamed—it safely outputs an informational message without throwing an error. Note that execution requires elevated administrator privileges to modify local user accounts.

.OUTPUTS
  Console output (Write-Host string messages indicating success or current state).
#>

# Define the old and new account names
$oldName = "Guest"
$newName = "rambo"

# Check if the Guest account exists
$guestAccount = Get-LocalUser -Name $oldName -ErrorAction SilentlyContinue

if ($guestAccount -ne $null) {
    # Rename the Guest account to mehmon
    Rename-LocalUser -Name $oldName -NewName $newName
    Write-Host "Guest account renamed to $newName successfully."
} else {
    Write-Host "The Guest account does not exist or is already renamed."
}