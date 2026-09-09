# Checagem pos-suspend: offsets + eventos + boot
$ErrorActionPreference = "Continue"
$out = "C:\Workspace\tools-pbo\check-suspend.txt"
$smu = "C:\Workspace\tools-pbo\ryzen-smu-cli\ryzen-smu-cli.exe"

"=== CHECK POS-SUSPEND $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $out

"--- offsets atuais ---" | Out-File $out -Append
& $smu --get-offsets-terse 2>&1 | Out-File $out -Append

"--- uptime do boot atual ---" | Out-File $out -Append
$os = Get-CimInstance Win32_OperatingSystem
"boot: $($os.LastBootUpTime) | uptime: $((Get-Date) - $os.LastBootUpTime)" | Out-File $out -Append

"--- eventos criticos ultima 1h ---" | Out-File $out -Append
$ev = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddMinutes(-60)} -ErrorAction SilentlyContinue
if ($ev) {
  $ev | Select-Object -First 15 | ForEach-Object { "id=$($_.Id) prov=$($_.ProviderName) $($_.TimeCreated.ToString('HH:mm:ss'))" | Out-File $out -Append }
} else { "nenhum evento critico" | Out-File $out -Append }

"--- WHEA ultima 1h ---" | Out-File $out -Append
$w = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddMinutes(-60)} -ErrorAction SilentlyContinue
if ($w) { $w | ForEach-Object { "WHEA: $($_.TimeCreated) id=$($_.Id)" | Out-File $out -Append } } else { "nenhum WHEA" | Out-File $out -Append }

"--- Kernel-Power / retomada / desligamento inesperado ---" | Out-File $out -Append
$kp = Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=(Get-Date).AddMinutes(-60)} -ErrorAction SilentlyContinue | Where-Object { $_.Id -in 41,42,107,506,507,6008,1 -or $_.ProviderName -match "Power-Troubleshooter" } | Select-Object -First 10
if ($kp) { $kp | ForEach-Object { "id=$($_.Id) prov=$($_.ProviderName) $($_.TimeCreated.ToString('HH:mm:ss'))" | Out-File $out -Append } } else { "nenhum" | Out-File $out -Append }
"=== FIM ===" | Out-File $out -Append
