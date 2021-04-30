# Set default execution policy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# If not already install chocolatey
if (-not (Get-Command "choco" -ErrorAction SilentlyContinue))
{
  Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Install requirements
choco install cascadiafonts cascadia-code-nerd-font firacode powershell-core vscode git hub -y

# Install powershell modules
Install-Module posh-git -Scope CurrentUser
Install-Module oh-my-posh -Scope CurrentUser
Install-Module -AllowClobber Get-ChildItemColor

# Copy profiles
New-Item -ItemType HardLink -Value (Join-Path (Get-Location) 'Powershell/Profile.ps1') -Path (Join-Path (Split-Path $profile) 'Profile.ps1') -Force
New-Item -ItemType HardLink -Value Powershell/Microsoft.PowerShell_profile.ps1 -Path (Join-Path (Split-Path $profile) 'Microsoft.PowerShell_profile.ps1') -Force

# Copy windows terminal settings (assumes this is run within it already)
New-Item -ItemType HardLink -Value WindowsTerminal/settings.json -Path (Resolve-Path (Join-Path $ENV:LOCALAPPDATA '/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json')) -Force

# Enable ssh-agent
Get-Service ssh-agent | Set-Service -StartupType Automatic
[Environment]::SetEnvironmentVariable("GIT_SSH", "$((Get-Command ssh).Source)", [System.EnvironmentVariableTarget]::User)
