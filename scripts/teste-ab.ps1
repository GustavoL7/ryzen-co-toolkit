# Teste A/B de offsets: mesma carga sintetica, telemetria durante a carga, checagem WHEA
# Uso:
#   .\teste-ab.ps1 -OffsetB "-25,-25,-25,-25,-25,-25" -Segundos 120 -Threads 12 -TimeoutSeg 180
#   -OffsetA vazio = baseline (NAO toca nos offsets na fase A)
#   No fim, deixa o OffsetB aplicado (volatil - reboot restaura BIOS)
param(
  [string]$OffsetA = "",
  [string]$OffsetB = "-25,-25,-25,-25,-25,-25",
  [int]$Segundos = 120,
  [int]$Threads = 12,
  [int]$TimeoutSeg = ($Segundos + 60)
)
$ErrorActionPreference = "Continue"
if ($TimeoutSeg -le 0) { $TimeoutSeg = $Segundos + 60 }
$root = Split-Path -Parent $PSScriptRoot
$smu = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe"
$dll = Join-Path $root "tools\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"
$logDir = Join-Path $root "logs"
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$script:logFile = Join-Path $logDir ("teste-ab-" + $ts + ".log")

function Write-Log {
  param([string]$Message)
  Write-Host $Message
  try { Add-Content -LiteralPath $script:logFile -Value $Message -Encoding UTF8 } catch {}
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  . (Join-Path $PSScriptRoot "lib\Elevacao.ps1")
  Invoke-Elevado -ScriptPath $PSCommandPath -Argumentos "-OffsetA `"$OffsetA`" -OffsetB `"$OffsetB`" -Segundos $Segundos -Threads $Threads -TimeoutSeg $TimeoutSeg"
  exit
}

if (-not (Test-Path -LiteralPath $dll)) {
  Write-Log "ERRO: LibreHardwareMonitorLib.dll nao encontrada em $dll. Rode scripts\1-baixar-ferramentas.ps1 primeiro."
  exit 1
}
Add-Type -Path $dll

function Read-Cpu {
  param($label)
  $c = New-Object LibreHardwareMonitor.Hardware.Computer
  $c.IsCpuEnabled = $true
  $c.Open() | Out-Null
  Start-Sleep -Seconds 2
  foreach ($hw in $c.Hardware) {
    if ($hw.HardwareType -eq "Cpu") {
      $hw.Update() | Out-Null
      $temp = ($hw.Sensors | Where-Object { $_.SensorType -eq "Temperature" -and $_.Name -match "Tctl" }).Value
      $pwr  = ($hw.Sensors | Where-Object { $_.SensorType -eq "Power" -and $_.Name -eq "Package" }).Value
      $svi2 = ($hw.Sensors | Where-Object { $_.SensorType -eq "Voltage" -and $_.Name -eq "Core (SVI2 TFN)" }).Value
      $clk  = ($hw.Sensors | Where-Object { $_.SensorType -eq "Clock" -and $_.Name -eq "Cores (Average)" }).Value
      $eff  = ($hw.Sensors | Where-Object { $_.SensorType -eq "Clock" -and $_.Name -eq "Cores (Average Effective)" }).Value
      if ($null -eq $temp -or $null -eq $pwr -or $null -eq $svi2 -or $null -eq $clk -or $null -eq $eff) {
        Write-Log "ERRO: sensores indisponiveis (LibreHardwareMonitor nao retornou Tctl/PPT/SVI2/clocks). Rode como admin e confira o LibreHardwareMonitor."
        $c.Close() | Out-Null
        exit 1
      }
      Write-Log ("{0}: Tctl={1}C | PPT={2}W | SVI2={3}V | clkMed={4}MHz | effMed={5}MHz" -f `
        $label, [math]::Round($temp,1), [math]::Round($pwr,1), [math]::Round($svi2,3), `
        [math]::Round($clk,0), [math]::Round($eff,0))
    }
  }
  $c.Close() | Out-Null
}

function Burn {
  param([int]$seconds, [int]$ThreadCount)
  $sb = { param($s) $end = (Get-Date).AddSeconds($s); $x = 1.234567; while ((Get-Date) -lt $end) { for ($k = 0; $k -lt 3000; $k++) { $x = [math]::Sqrt($x * 1.000001 + $k * 0.0000001) + 0.0000001; $x = [math]::Sin($x) + [math]::Cos($x) + 2.0 } } }
  $list = @()
  for ($i = 1; $i -le $ThreadCount; $i++) { $list += Start-Job -ScriptBlock $sb -ArgumentList $seconds }
  return $list
}

function Stop-Burn {
  param($Jobs)
  if ($null -eq $Jobs) { return }
  foreach ($j in $Jobs) { try { Stop-Job -Job $j -ErrorAction SilentlyContinue } catch {} }
  foreach ($j in $Jobs) { try { Remove-Job -Job $j -Force -ErrorAction SilentlyContinue } catch {} }
}

function Check-Whea {
  param($minutos)
  $w = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddMinutes(-$minutos)} -ErrorAction SilentlyContinue
  if ($w) { $w | ForEach-Object { Write-Log ("WHEA: {0} id={1}" -f $_.TimeCreated, $_.Id) } } else { Write-Log "nenhum WHEA" }
}

$half = [math]::Floor($Segundos / 2)

Write-Log "=== TESTE A/B start $(Get-Date -Format 'HH:mm:ss') ==="
Write-Log "Params: Segundos=$Segundos Threads=$Threads TimeoutSeg=$TimeoutSeg"
Write-Log "--- offset atual ---"
try { $o = (& $smu --get-offsets-terse 2>&1 | Out-String); Write-Log $o } catch { Write-Log ("ERRO ao ler offsets: {0}" -f $_.Exception.Message); exit 1 }

Write-Log "--- fase A: burn $Segundos s ($Threads threads) ---"
if (-not [string]::IsNullOrEmpty($OffsetA)) {
  try { $oa = (& $smu --offset $OffsetA 2>&1 | Out-String); Write-Log $oa } catch { Write-Log ("ERRO ao aplicar OffsetA: {0}" -f $_.Exception.Message); exit 1 }
} else {
  Write-Log "fase A: baseline, sem tocar nos offsets (OffsetA vazio)"
}
$jobs = Burn -seconds $Segundos -ThreadCount $Threads
Start-Sleep -Seconds ($half + 5)
Read-Cpu "A"
$rest = $TimeoutSeg - ($half + 5)
if ($rest -lt 5) { $rest = 5 }
$null = Wait-Job -Job $jobs -Timeout $rest
$still = @($jobs | Where-Object { $_.State -eq "Running" })
if ($still.Count -gt 0) {
  Stop-Burn -Jobs $jobs
  Write-Log ("TIMEOUT fase A: limite {0}s estourado, jobs do teste encerrados." -f $TimeoutSeg)
  Write-Log "RESULTADO: FALHA (timeout) exit=2"
  exit 2
}
Stop-Burn -Jobs $jobs

Write-Log "--- aplicando fase B: $OffsetB ---"
try { $ob = (& $smu --offset $OffsetB 2>&1 | Out-String); Write-Log $ob } catch { Write-Log ("ERRO ao aplicar OffsetB: {0}" -f $_.Exception.Message); exit 1 }
try { $oc = (& $smu --get-offsets-terse 2>&1 | Out-String); Write-Log $oc } catch { Write-Log ("ERRO ao ler offsets: {0}" -f $_.Exception.Message); exit 1 }

Write-Log "--- fase B: burn $Segundos s ($Threads threads) ---"
$jobs = Burn -seconds $Segundos -ThreadCount $Threads
Start-Sleep -Seconds ($half + 5)
Read-Cpu "B"
$rest = $TimeoutSeg - ($half + 5)
if ($rest -lt 5) { $rest = 5 }
$null = Wait-Job -Job $jobs -Timeout $rest
$still = @($jobs | Where-Object { $_.State -eq "Running" })
if ($still.Count -gt 0) {
  Stop-Burn -Jobs $jobs
  Write-Log ("TIMEOUT fase B: limite {0}s estourado, jobs do teste encerrados." -f $TimeoutSeg)
  Write-Log "RESULTADO: FALHA (timeout) exit=2"
  exit 2
}
Stop-Burn -Jobs $jobs

Write-Log "--- WHEA ultima 30 min ---"
Check-Whea 30
Write-Log "=== fim $(Get-Date -Format 'HH:mm:ss') ==="
Write-Log "AVISO: Offset B ($OffsetB) esta aplicado agora (volatil - reboot restaura BIOS). Rode o CPU-Z bench para validar o score!"
Write-Log ("Log salvo em: {0}" -f $script:logFile)
