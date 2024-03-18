$global:DefaultUser = $env:UserName

Import-Module posh-git

Invoke-Expression (&starship init powershell)
