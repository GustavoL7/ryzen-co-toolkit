# Pass 1: baseline -15 (BIOS) vs -20 all-core, mesma carga, com telemetria
$ErrorActionPreference = "Continue"
$out = "C:\Workspace\tools-pbo\pass1-result.txt"
$smu = "C:\Workspace\tools-pbo\ryzen-smu-cli\ryzen-smu-cli.exe"
$dll = "C:\Workspace\tools-pbo\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"
Add-Type -Path $dll

function Read-Cpu {
  param($label, $secondsIn)
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
      $minC = ($hw.Sensors | Where-Object { $_.SensorType -eq "Clock" -and $_.Name -match "^Core #" -and $_.Name -notmatch "Effective|Average" } | Measure-Object Value -Minimum).Minimum
      $maxC = ($hw.Sensors | Where-Object { $_.SensorType -eq "Clock" -and $_.Name -match "^Core #" -and $_.Name -notmatch "Effective|Average" } | Measure-Object Value -Maximum).Maximum
      "{0} @t+{1}s: Tctl={2}C | PPT={3}W | SVI2={4}V | clkMed={5}MHz | effMed={6}MHz | clkMin={7} | clkMax={8}" -f $label, $secondsIn, [math]::Round($temp,1), [math]::Round($pwr,1), [math]::Round($svi2,3), [math]::Round($clk,0), [math]::Round($eff,0), [math]::Round($minC,0), [math]::Round($maxC,0) | Out-File $out -Append
    }
  }
  $c.Close() | Out-Null
}

function Burn {
  param($seconds)
  $sb = { param($s) $end = (Get-Date).AddSeconds($s); while ((Get-Date) -lt $end) { $x = 1.000001; $x = [math]::Sqrt($x * 1.000001) + 0.0000001 } }
  $jobs = 1..11 | ForEach-Object { Start-Job -ScriptBlock $sb -ArgumentList $seconds }
  $jobs
}

"=== PASS1 start $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $out
& $smu --get-offsets-terse 2>&1 | Out-File $out -Append

"--- fase A: burn com -15 (BIOS) ---" | Out-File $out -Append
$j = Burn 150
Start-Sleep -Seconds 95
Read-Cpu "A(-15)" 100
Start-Sleep -Seconds 60
Get-Job | Stop-Job; Get-Job | Remove-Job -Force

"--- aplicando -20 all-core ---" | Out-File $out -Append
& $smu --offset "-20,-20,-20,-20,-20,-20" 2>&1 | Out-File $out -Append
& $smu --get-offsets-terse 2>&1 | Out-File $out -Append

"--- fase B: burn com -20 ---" | Out-File $out -Append
$j = Burn 150
Start-Sleep -Seconds 95
Read-Cpu "B(-20)" 100
Start-Sleep -Seconds 60
Get-Job | Stop-Job; Get-Job | Remove-Job -Force

"--- WHEA ultima 15 min ---" | Out-File $out -Append
$w = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddMinutes(-15)} -ErrorAction SilentlyContinue
if ($w) { $w | ForEach-Object { "WHEA: $($_.TimeCreated) id=$($_.Id)" | Out-File $out -Append } } else { "nenhum WHEA" | Out-File $out -Append }

"=== PASS1 fim $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $out -Append
