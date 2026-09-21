# Aplica ajustes de SO: plano High performance + unpark 100% (powercfg.exe apenas)
# Uso: .\aplicar-os.ps1 [-WhatIf]   (idempotente; exit 0; NUNCA mexe em SMU/CO/BIOS)
# -WhatIf = dry-run: mostra os comandos sem executar (nao exige admin, nao escreve nada).
param(
  [switch]$WhatIf
)
$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $ScriptDir "lib\Idioma.ps1")

$GuidBalanced = "381b4222-f694-41f0-9685-ff5bb260df2e"
$GuidSaver = "a1841308-3541-4fab-bc81-f71556f20b4a"
$SubProc = "54533251-82d8-4824-96c1-47b60b740d00"
$MinCores = "0cc5b647-c1df-4637-891a-dec35c318583"
$ThrottleMin = "893dee8e-2bef-41e0-89c6-b55d0929964c"

function Get-PlanoResumo {
  try {
    $linhas = & powercfg.exe /getactivescheme 2>$null
    if ($null -eq $linhas) { return "" }
    $txt = (($linhas | Out-String).Trim())
    if ([string]::IsNullOrWhiteSpace($txt)) { return "" }
    return ($txt -split "`r?`n" | Select-Object -First 1).Trim()
  } catch { return "" }
}

function Test-PrecisaPlano {
  param([string]$Resumo)
  if ([string]::IsNullOrWhiteSpace($Resumo)) { return $true }
  $m = [regex]::Match($Resumo, "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
  if ($m.Success) {
    $g = $m.Value.ToLowerInvariant()
    if (($g -eq $GuidBalanced) -or ($g -eq $GuidSaver)) { return $true }
    return $false
  }
  if ($Resumo -match "Saver|Economia|Balanced|Equilibrado") { return $true }
  return $false
}

$cmdPlano = "powercfg.exe /setactive SCHEME_MIN"
$cmdsUnpark = @(
  "powercfg.exe /setacvalueindex SCHEME_CURRENT $SubProc $MinCores 100",
  "powercfg.exe /setdcvalueindex SCHEME_CURRENT $SubProc $MinCores 100",
  "powercfg.exe /setacvalueindex SCHEME_CURRENT $SubProc $ThrottleMin 100",
  "powercfg.exe /setdcvalueindex SCHEME_CURRENT $SubProc $ThrottleMin 100",
  "powercfg.exe /setactive SCHEME_CURRENT"
)

Write-Host (Get-Texto "a_os_titulo")
Write-Host ""

$plano = Get-PlanoResumo
$precisaPlano = Test-PrecisaPlano $plano

if ($WhatIf) {
  if ($precisaPlano) {
    Write-Host (Get-Texto "a_os_whatif" $cmdPlano)
  } else {
    if ([string]::IsNullOrWhiteSpace($plano)) { $plano = (Get-Texto "c_sem_dados") }
    Write-Host (Get-Texto "a_os_plano_mantem" $plano)
  }
  foreach ($c in $cmdsUnpark) {
    Write-Host (Get-Texto "a_os_whatif" $c)
  }
  Write-Host (Get-Texto "a_os_timer")
  Write-Host (Get-Texto "a_os_nada")
  exit 0
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  . (Join-Path $ScriptDir "lib\Elevacao.ps1")
  Invoke-Elevado -ScriptPath $PSCommandPath
  Write-Host (Get-Texto "a_os_admin")
  exit 0
}

if ($precisaPlano) {
  Write-Host (Get-Texto "a_os_plano_troca")
} else {
  if ([string]::IsNullOrWhiteSpace($plano)) { $plano = (Get-Texto "c_sem_dados") }
  Write-Host (Get-Texto "a_os_plano_mantem" $plano)
}
Write-Host (Get-Texto "a_os_unpark")
$conf = Read-Host (Get-Texto "g_confirma")
if (($conf -ne "S") -and ($conf -ne "s") -and ($conf -ne "Y") -and ($conf -ne "y")) {
  Write-Host (Get-Texto "g_cancel_nada")
  exit 0
}

if ($precisaPlano) {
  try { & powercfg.exe /setactive SCHEME_MIN } catch {}
}
try { & powercfg.exe /setacvalueindex SCHEME_CURRENT $SubProc $MinCores 100 } catch {}
try { & powercfg.exe /setdcvalueindex SCHEME_CURRENT $SubProc $MinCores 100 } catch {}
try { & powercfg.exe /setacvalueindex SCHEME_CURRENT $SubProc $ThrottleMin 100 } catch {}
try { & powercfg.exe /setdcvalueindex SCHEME_CURRENT $SubProc $ThrottleMin 100 } catch {}
try { & powercfg.exe /setactive SCHEME_CURRENT } catch {}

Write-Host (Get-Texto "a_os_ok")
Write-Host (Get-Texto "a_os_timer")
Write-Host (Get-Texto "a_os_reverte")

exit 0
