# Set default execution policy

Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# If not already install chocolatey
if (-not (Get-Command "choco" -ErrorAction SilentlyContinue))
{
  Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Install requirements
choco install cascadiafonts git hub

# Install powershell modules
Install-Module posh-git -Scope CurrentUser
Install-Module oh-my-post -Scope CurrentUser
Install-Module -AllowClobber Get-ChildItemColor

# Copy profiles
Copy-Item Powershell/Profile.ps1 (Split-Path $profile)
Copy-Item Powershell/Microsoft.PowerShell_profile.ps1 (Split-Path $profile)

# Copy windows terminal settings (assumes this is run within it already)
Copy-Item WindowsTerminal/settings.json (Join-Path $ENV:LOCALAPPDATA '/Packages/Microsoft.WindowsTerminal_*/LocalState/')

# Enable ssh-agent
Get-Service ssh-agent | Set-Service -StartupType Automatic
[Environment]::SetEnvironmentVariable("GIT_SSH", "$((Get-Command ssh).Source)", [System.EnvironmentVariableTarget]::User)
