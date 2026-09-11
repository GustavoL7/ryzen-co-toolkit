# Teste: leitura de sensores CPU via LibreHardwareMonitorLib
$ErrorActionPreference = "Stop"
$out = "C:\Workspace\tools-pbo\sensors.txt"
$dll = "C:\Workspace\tools-pbo\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"
try {
  Add-Type -Path $dll
  $c = New-Object LibreHardwareMonitor.Hardware.Computer
  $c.IsCpuEnabled = $true
  $c.Open() | Out-Null
  foreach ($hw in $c.Hardware) {
    if ($hw.HardwareType -eq "Cpu") {
      $hw.Update() | Out-Null
      "HW: $($hw.Name)" | Out-File $out
      foreach ($s in $hw.Sensors) {
        "{0} | {1} | {2} | {3}" -f $s.SensorType, $s.Name, [math]::Round($s.Value, 2), $s.Identifier | Out-File $out -Append
      }
    }
  }
  $c.Close() | Out-Null
  "OK" | Out-File $out -Append
} catch {
  "ERRO: $($_.Exception.Message)" | Out-File $out -Append
}
