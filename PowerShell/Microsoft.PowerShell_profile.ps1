$global:DefaultUser = $env:UserName
$env:POSH_SESSION_DEFAULT_USER = $env:UserName

Import-Module posh-git
Import-Module oh-my-posh

Set-PoshPrompt ~/.agnoster.omp.json
