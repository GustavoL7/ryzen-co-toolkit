# Teste A/B de offsets: mesma carga sintetica, telemetria durante a carga, checagem WHEA
# Uso:
#   .\teste-ab.ps1 -OffsetB "-25,-25,-25,-25,-25,-25" -Segundos 120
#   -OffsetA vazio = usa os offsets ATIVOS agora (baseline) sem mudar nada na fase A
#   No fim, deixa o OffsetB aplicado (volatil - reboot restaura BIOS)
param(
  [string]$OffsetA = "",
  [string]$OffsetB = "-25,-25,-25,-25,-25,-25",
  [int]$Segundos = 120
)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$smu = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe"
$dll = Join-Path $root "tools\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "Pedindo elevacao (admin) - confirme o UAC..."
  Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"","-OffsetA","`"$OffsetA`"","-OffsetB","`"$OffsetB`"","-Segundos",$Segundos
  exit
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
      Write-Host ("{0}: Tctl={1}C | PPT={2}W | SVI2={3}V | clkMed={4}MHz | effMed={5}MHz" -f `
        $label, [math]::Round($temp,1), [math]::Round($pwr,1), [math]::Round($svi2,3), `
        [math]::Round($clk,0), [math]::Round($eff,0))
    }
  }
  $c.Close() | Out-Null
}

function Burn {
  param($seconds)
  $sb = { param($s) $end = (Get-Date).AddSeconds($s); while ((Get-Date) -lt $end) { $x = 1.000001; $x = [math]::Sqrt($x * 1.000001) + 0.0000001 } }
  1..11 | ForEach-Object { Start-Job -ScriptBlock $sb -ArgumentList $seconds }
}

function Stop-Burn {
  Get-Job | Stop-Job; Get-Job | Remove-Job -Force
}

function Check-Whea {
  param($minutos)
  $w = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddMinutes(-$minutos)} -ErrorAction SilentlyContinue
  if ($w) { $w | ForEach-Object { Write-Host ("WHEA: {0} id={1}" -f $_.TimeCreated, $_.Id) } } else { Write-Host "nenhum WHEA" }
}

$half = [math]::Floor($Segundos / 2)

Write-Host "=== TESTE A/B start $(Get-Date -Format 'HH:mm:ss') ==="
Write-Host "--- offset atual ---"
& $smu --get-offsets-terse

Write-Host "--- fase A: burn $Segundos s ---"
if (-not [string]::IsNullOrEmpty($OffsetA)) {
  & $smu --offset $OffsetA
}
$j = Burn $Segundos
Start-Sleep -Seconds ($half + 5)
Read-Cpu "A"
Stop-Burn

Write-Host "--- aplicando fase B: $OffsetB ---"
& $smu --offset $OffsetB
& $smu --get-offsets-terse

Write-Host "--- fase B: burn $Segundos s ---"
$j = Burn $Segundos
Start-Sleep -Seconds ($half + 5)
Read-Cpu "B"
Stop-Burn

Write-Host "--- WHEA ultima 30 min ---"
Check-Whea 30
Write-Host "=== fim $(Get-Date -Format 'HH:mm:ss') ==="
Write-Host "Offset B esta aplicado agora (volatil). Rode o CPU-Z bench para validar o score!"
