# Le sensores de CPU via LibreHardwareMonitorLib (Tctl, PPT, SVI2, clocks, effective clocks)
# Uso: .\ler-sensores.ps1 [-LoopSeconds 10]   (loop continuo ate Ctrl+C)
param(
  [int]$LoopSeconds = 0
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dll = Join-Path $root "tools\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  . (Join-Path $PSScriptRoot "lib\Elevacao.ps1")
  Invoke-Elevado -ScriptPath $PSCommandPath -Argumentos "-LoopSeconds $LoopSeconds"
  exit
}

if (-not (Test-Path -LiteralPath $dll)) {
  Write-Host "ERRO: LibreHardwareMonitorLib.dll nao encontrada em $dll. Rode scripts\1-baixar-ferramentas.ps1 primeiro."
  exit 1
}
Add-Type -Path $dll

function Show-Cpu {
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
        Write-Host "ERRO: sensores indisponiveis (LibreHardwareMonitor nao retornou Tctl/PPT/SVI2/clocks). Rode como admin e confira o LibreHardwareMonitor."
        $c.Close() | Out-Null
        exit 1
      }
      if ($clk -eq 0) {
        Write-Host "ERRO: clock medio = 0, impossivel calcular stretch (divisao por zero)."
        $c.Close() | Out-Null
        exit 1
      }
      Write-Host ("Tctl={0}C | PPT={1}W | SVI2={2}V | clkMed={3}MHz | effMed={4}MHz | stretch={5}%" -f `
        [math]::Round($temp,1), [math]::Round($pwr,1), [math]::Round($svi2,3), `
        [math]::Round($clk,0), [math]::Round($eff,0), `
        [math]::Round(($eff / $clk) * 100, 1))
      Write-Host "--- sensores completos ---"
      foreach ($s in $hw.Sensors) {
        Write-Host ("{0,-11} | {1,-28} | {2}" -f $s.SensorType, $s.Name, [math]::Round($s.Value, 2))
      }
    }
  }
  $c.Close() | Out-Null
}

if ($LoopSeconds -gt 0) {
  while ($true) {
    Show-Cpu
    Start-Sleep -Seconds $LoopSeconds
  }
} else {
  Show-Cpu
}
