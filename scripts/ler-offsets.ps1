# Le os offsets CO ativos (o que a BIOS/CLI tem agora) e o PBO scalar
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$smu = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  . (Join-Path $PSScriptRoot "lib\Elevacao.ps1")
  Invoke-Elevado -ScriptPath $PSCommandPath
  exit
}

Write-Host "=== Offsets CO atuais (por core fisico) ==="
& $smu --get-offsets-terse
Write-Host "=== PBO scalar ==="
& $smu --get-pbo-scalar
Write-Host ""
Write-Host "Nota: offsets -30 = teto AGESA. Se acabou de suspender/rebootar, estes sao os valores da BIOS."
