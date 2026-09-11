# 2 - Registra a task agendada "PBO-Runner" (dispatcher elevado)
# Voce confirma o UAC UMA vez; depois todos os scripts rodam sem novo UAC.
# Requer: exec.ps1 na raiz do repo.
# NOTA: sem ACL-stripping aqui — o fluxo exige escritor de cmd.txt e leitor de
# logs/out.txt NAO-elevados (mesmo usuario interativo); a garantia e a
# validacao de conteudo no exec.ps1 (allowlist + 1 linha + deny-chars + path confinado ao $root).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$execPath = Join-Path $root "exec.ps1"

if (-not (Test-Path $execPath)) { throw "exec.ps1 nao encontrado em $root" }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "Pedindo elevacao (admin) - confirme o UAC..."
  Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`""
  exit
}

$a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$execPath`""
$p = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "PBO-Runner" -Action $a -Principal $p -Settings $s -Force | Out-Null

Write-Host "=== Task 'PBO-Runner' registrada com RunLevel Highest ==="

$logsDir = Join-Path $root "logs"
if (-not (Test-Path -LiteralPath $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }
$outFile = Join-Path $logsDir "out.txt"
if (-not (Test-Path -LiteralPath $outFile)) { New-Item -ItemType File -Path $outFile -Force | Out-Null }
$cmdPath = Join-Path $root "cmd.txt"
$smuExe = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe"
Set-Content -Path $cmdPath -Value "`"$smuExe`" --get-offsets-terse" -Encoding ASCII

Write-Host "Teste:"
Write-Host "task registrada - rode: Start-ScheduledTask -TaskName PBO-Runner; depois veja logs\out.txt"
