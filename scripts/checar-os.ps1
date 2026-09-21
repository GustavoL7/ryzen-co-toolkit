# OS read-only check: power plan, core parking, timer resolution, standby list, timer tools
# Uso: .\checar-os.ps1   (somente leitura: nao altera nada, nao exige admin; exit 0 sempre)
$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $ScriptDir "lib\Idioma.ps1")

function Get-PlanoAtivo {
  try {
    $linhas = & powercfg.exe /getactivescheme 2>$null
    if ($null -eq $linhas) { return $null }
    $txt = (($linhas | Out-String).Trim())
    if ([string]::IsNullOrWhiteSpace($txt)) { return $null }
    return ($txt -split "`r?`n" | Select-Object -First 1).Trim()
  } catch { return $null }
}

function Get-CoreParking {
  $info = ""
  try {
    $q = & powercfg.exe /query SCHEME_CURRENT SUB_PROCESSOR 2>$null
    if ($null -ne $q) { $info = (($q | Out-String).Trim()) }
  } catch {}
  $reg = ""
  try {
    $rk = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\0cc5b647-c1df-4637-891a-dec35c318583"
    if (Test-Path -LiteralPath $rk) {
      $p = Get-ItemProperty -LiteralPath $rk -ErrorAction SilentlyContinue
      if (($null -ne $p) -and ($null -ne $p.Attributes)) { $reg = ("Attributes={0}" -f $p.Attributes) }
    }
  } catch {}
  if ([string]::IsNullOrWhiteSpace($info) -and [string]::IsNullOrWhiteSpace($reg)) { return $null }
  $linhas = @($info -split "`r?`n" | Where-Object { $_ -match "Setting Index|Minimum number of cores" } | Select-Object -First 6)
  $resumo = (($linhas -join " | ").Trim())
  if ([string]::IsNullOrWhiteSpace($resumo)) { $resumo = $reg }
  elseif (-not [string]::IsNullOrWhiteSpace($reg)) { $resumo = ($resumo + " | " + $reg) }
  if ($resumo.Length -gt 220) { $resumo = $resumo.Substring(0, 220) }
  if ([string]::IsNullOrWhiteSpace($resumo)) { return $null }
  return $resumo
}

function Get-TimerResolution {
  try {
    if (-not ([System.Management.Automation.PSTypeName]"OSCheck.TimerRes").Type) {
      Add-Type -Namespace OSCheck -Name TimerRes -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("ntdll.dll")]
public static extern int NtQueryTimerResolution(out uint MinimumResolution, out uint MaximumResolution, out uint CurrentResolution);
"@
    }
    [uint32]$min = 0
    [uint32]$max = 0
    [uint32]$cur = 0
    $rc = [OSCheck.TimerRes]::NtQueryTimerResolution([ref]$min, [ref]$max, [ref]$cur)
    if ($rc -ne 0) { return $null }
    return @{ MinMs = ([double]$min / 10000.0); MaxMs = ([double]$max / 10000.0); CurMs = ([double]$cur / 10000.0) }
  } catch { return $null }
}

function Format-Bytes {
  param([double]$Bytes)
  if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
  if ($Bytes -ge 1MB) { return ("{0:N0} MB" -f ($Bytes / 1MB)) }
  return ("{0:N0} KB" -f ($Bytes / 1KB))
}

function Get-StandbyMem {
  $sb = $null
  try {
    $paths = @("\Memory\Standby Cache Normal Priority Bytes", "\Memory\Standby Cache Reserve Bytes", "\Memory\Standby Cache Core Bytes")
    $amostra = Get-Counter -Counter $paths -ErrorAction SilentlyContinue
    if ($null -ne $amostra) {
      $soma = ($amostra.CounterSamples | Measure-Object -Property CookedValue -Sum -ErrorAction SilentlyContinue).Sum
      if ($null -ne $soma) { $sb = [double]$soma }
    }
  } catch {}
  $livre = $null
  $tot = $null
  try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($null -ne $os) {
      $livre = ([double]$os.FreePhysicalMemory * 1KB)
      $tot = ([double]$os.TotalVisibleMemorySize * 1KB)
    }
  } catch {}
  if (($null -eq $sb) -and ($null -eq $livre)) { return $null }
  return @{ Standby = $sb; Livre = $livre; Total = $tot }
}

function Get-FerramentasTimer {
  $achadas = @()
  $nomes = @("ISLC", "TimerTool", "ParkControl", "ProcessLasso")
  foreach ($n in $nomes) {
    try {
      if ($null -ne (Get-Process -Name $n -ErrorAction SilentlyContinue)) {
        if ($achadas -notcontains $n) { $achadas += $n }
      }
    } catch {}
  }
  $arquivos = @()
  try { $arquivos += (Join-Path $env:ProgramFiles "Intelligent standby list cleaner\ISLC.exe") } catch {}
  try { $arquivos += (Join-Path ${env:ProgramFiles(x86)} "Intelligent standby list cleaner\ISLC.exe") } catch {}
  try { $arquivos += (Join-Path (Split-Path -Parent $ScriptDir) "tools\ISLC.exe") } catch {}
  foreach ($f in $arquivos) {
    try {
      if (-not [string]::IsNullOrWhiteSpace($f)) {
        if (Test-Path -LiteralPath $f) {
          if ($achadas -notcontains "ISLC") { $achadas += "ISLC" }
        }
      }
    } catch {}
  }
  return $achadas
}

Write-Host (Get-Texto "c_titulo")
Write-Host ""

$plano = Get-PlanoAtivo
if ($null -eq $plano) {
  Write-Host (Get-Texto "c_plano" (Get-Texto "c_sem_dados"))
  Write-Host ("=> " + (Get-Texto "c_aviso"))
} else {
  Write-Host (Get-Texto "c_plano" $plano)
  if ($plano -match "Saver|Economia") { Write-Host ("=> " + (Get-Texto "c_aviso")) }
  else { Write-Host ("=> " + (Get-Texto "c_ok")) }
}
Write-Host (Get-Texto "c_plano_tip")
Write-Host ""

$park = Get-CoreParking
if ($null -eq $park) {
  Write-Host (Get-Texto "c_park" (Get-Texto "c_sem_dados"))
  Write-Host ("=> " + (Get-Texto "c_aviso"))
} else {
  Write-Host (Get-Texto "c_park" $park)
  if ($park -match "0x00000064") { Write-Host ("=> " + (Get-Texto "c_ok")) }
  else { Write-Host ("=> " + (Get-Texto "c_aviso")) }
}
Write-Host (Get-Texto "c_park_tip")
Write-Host ""

$timer = Get-TimerResolution
if ($null -eq $timer) {
  Write-Host (Get-Texto "c_timer" (Get-Texto "c_sem_dados") "?" "?")
  Write-Host ("=> " + (Get-Texto "c_aviso"))
} else {
  $cur = ("{0:N4}" -f $timer.CurMs)
  $tmin = ("{0:N4}" -f $timer.MinMs)
  $tmax = ("{0:N4}" -f $timer.MaxMs)
  Write-Host (Get-Texto "c_timer" $cur $tmin $tmax)
  if ($timer.CurMs -le 1.0) { Write-Host ("=> " + (Get-Texto "c_ok")) }
  else { Write-Host ("=> " + (Get-Texto "c_aviso")) }
}
Write-Host (Get-Texto "c_timer_tip")
Write-Host ""

$mem = Get-StandbyMem
if ($null -eq $mem) {
  Write-Host (Get-Texto "c_standby" (Get-Texto "c_sem_dados") "?" "?")
  Write-Host ("=> " + (Get-Texto "c_aviso"))
} else {
  $s = "?"
  $l = "?"
  $t = "?"
  if ($null -ne $mem.Standby) { $s = Format-Bytes $mem.Standby }
  if ($null -ne $mem.Livre) { $l = Format-Bytes $mem.Livre }
  if ($null -ne $mem.Total) { $t = Format-Bytes $mem.Total }
  Write-Host (Get-Texto "c_standby" $s $l $t)
  if ($null -ne $mem.Standby) { Write-Host ("=> " + (Get-Texto "c_ok")) }
  else { Write-Host ("=> " + (Get-Texto "c_aviso")) }
}
Write-Host (Get-Texto "c_standby_tip")
Write-Host ""

$tools = Get-FerramentasTimer
if (($null -eq $tools) -or ($tools.Count -eq 0)) {
  Write-Host (Get-Texto "c_tools" (Get-Texto "c_tools_none"))
  Write-Host ("=> " + (Get-Texto "c_aviso"))
} else {
  Write-Host (Get-Texto "c_tools" ($tools -join ", "))
  Write-Host ("=> " + (Get-Texto "c_ok"))
}
Write-Host (Get-Texto "c_tools_tip")

exit 0
