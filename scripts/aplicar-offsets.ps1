# Aplica offsets CO via SMU (sobrepoe a BIOS ate reboot/suspend)
# Uso: .\aplicar-offsets.ps1 -Offsets "-30,-30,-30,-30,-30,-30"
param(
  [Parameter(Mandatory = $true)][string]$Offsets
)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$smu = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "Pedindo elevacao (admin) - confirme o UAC..."
  Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"","-Offsets","`"$Offsets`""
  exit
}

Write-Host "=== Aplicando offsets: $Offsets ==="
& $smu --offset $Offsets
Write-Host "=== Estado atual ==="
& $smu --get-offsets-terse
Write-Host ""
Write-Host "AVISO: volatil! Suspend/reboot restaura os valores da BIOS."
Write-Host "Grave o valor vencedor na BIOS: Advanced > AMD Overclocking > PBO > Curve Optimizer"
