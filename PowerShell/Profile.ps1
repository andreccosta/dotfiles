function Get-CurrentDir {
  Write-Output (Get-Item -Path .).FullName
}

function Get-PartialMatchDir() {
  Push-Location
  foreach ($arg in $args) {
    if (Test-Path $arg -PathType Container) {
      $path = Resolve-Path -Relative $arg

      if ($path -is [string]) {
        Set-Location $path
        Continue
      }
    }
    elseif (Test-Path ($arg + "*") -PathType Container) {
      $path = Resolve-Path -Relative ($arg + "*")

      if ($path -is [string]) {
        Set-Location $path
        Continue
      }
    }

    Write-Output "Could not find matching path for: '${arg}'"
    Pop-Location
    Break
  }
}

function Subst-CurrentDir([string] $drive = "X:") {
  if ($drive -notmatch '.+?:$') {
    $drive += ":"
  }

  $path = (Get-Item -Path .).FullName
  Write-Output "subst ${drive} ${path}"

  # subst as the current user
  try { subst /D $drive | Out-Null } catch { }
  subst $drive $path

  # subst as administrator
  If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $proc = Start-Process powershell -WindowStyle hidden -Verb runAs -ArgumentList "-NonInteractive cd ${path}; Subst-CurrentDir ${drive}" -WorkingDirectory $path -PassThru
    $proc | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
    Break
  }
}

function GoTo {
  param(
    [String]$key
  )

  process {
    $locations = @{
      "Code"            = "~/Code"
      "Home"            = "~"
      "Gh"              = "~/Code/src/github.com/andreccosta"
      "Github"          = "~/Code/src/github.com/andreccosta"
      "AoC"    = "~/Code/src/github.com/andreccosta/aoc"
      "AdventOfCode"    = "~/Code/src/github.com/andreccosta/aoc"
    }

    if (!$key) {
      $locations | Format-Table | Out-String | Write-Host
      return
    }

    $keys = $locations.Keys -match "(?i)^$key\w*"

    if ($keys -and $keys[0]) {
      Set-Location $locations[$keys[0]]
    }
    else {
      Write-Output "Unknown GoTo key ""$key""";
    }
  }
}

function Watch {
  param(
    [Int32]$seconds = 5,
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string]$command
  )

  while(1) {
    Clear-Host
    Invoke-Expression "$command"
    Start-Sleep -Seconds $seconds
  }
}

Set-Alias -Name "ccd" -Value Get-PartialMatchDir
Set-Alias -Name "scd" -Value Subst-CurrentDir

# Visual Studio
Set-Alias -Name "vs2019" -Value "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\devenv.exe"
Set-Alias -Name "vs" -Value "vs2019"

# Common apps
Set-Alias -Name "n" -Value "notepad++.exe"

# Go to
Set-Alias -Name "gt" -Value GoTo
Set-Alias -Name "g" -Value GoTo

# Build solution
Set-Alias -Name "b" -Value Build-Solution
Set-Alias -Name "build" -Value Build-Solution

# Set l and ls alias to use Get-ChildItemColor cmdlets
Set-Alias l Get-ChildItemColor -Option AllScope
Set-Alias ls Get-ChildItemColorFormatWide -Option AllScope

# Set python alias
Set-Alias -Name "py" -Value "python.exe"
Set-Alias -Name "python" -Value "python.exe"
