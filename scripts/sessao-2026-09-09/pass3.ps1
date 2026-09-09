# Pass 3: -30 all-core (limite AGESA), burn 120s, telemetria t+60s
$ErrorActionPreference = "Continue"
$out = "C:\Workspace\tools-pbo\pass3-result.txt"
$smu = "C:\Workspace\tools-pbo\ryzen-smu-cli\ryzen-smu-cli.exe"
$dll = "C:\Workspace\tools-pbo\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"
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
      "{0}: Tctl={1}C | PPT={2}W | SVI2={3}V | clkMed={4}MHz | effMed={5}MHz" -f $label, [math]::Round($temp,1), [math]::Round($pwr,1), [math]::Round($svi2,3), [math]::Round($clk,0), [math]::Round($eff,0) | Out-File $out -Append
    }
  }
  $c.Close() | Out-Null
}

"=== PASS3 start $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $out
& $smu --offset "-30,-30,-30,-30,-30,-30" 2>&1 | Out-File $out -Append
& $smu --get-offsets-terse 2>&1 | Out-File $out -Append

$sb = { param($s) $end = (Get-Date).AddSeconds($s); while ((Get-Date) -lt $end) { $x = 1.000001; $x = [math]::Sqrt($x * 1.000001) + 0.0000001 } }
$jobs = 1..11 | ForEach-Object { Start-Job -ScriptBlock $sb -ArgumentList 120 }
Start-Sleep -Seconds 60
Read-Cpu "B(-30)"
Get-Job | Stop-Job; Get-Job | Remove-Job -Force

$w = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddMinutes(-15)} -ErrorAction SilentlyContinue
if ($w) { $w | ForEach-Object { "WHEA: $($_.TimeCreated) id=$($_.Id)" | Out-File $out -Append } } else { "nenhum WHEA" | Out-File $out -Append }
"=== PASS3 fim $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $out -Append
