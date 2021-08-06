$global:DefaultUser = $env:UserName
$env:POSH_SESSION_DEFAULT_USER = $env:UserName

Import-Module posh-git

Invoke-Expression (&starship init powershell)
