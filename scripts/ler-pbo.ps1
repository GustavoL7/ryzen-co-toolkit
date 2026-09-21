# Le os limites PBO efetivos (PPT/TDC/EDC) via SMU (somente leitura; nunca escreve)
# Uso: .\ler-pbo.ps1   (sem params)
# Fallback honesto: se o ryzen-smu-cli desta versao nao tiver getter de limites,
# informa e sai com exit 0 (PPT atual via sensores; limites exatos no HWiNFO64).
$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $ScriptDir "lib\Idioma.ps1")
$root = Split-Path -Parent $ScriptDir
$smu = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  . (Join-Path $ScriptDir "lib\Elevacao.ps1")
  Invoke-Elevado -ScriptPath $PSCommandPath
  exit
}

Write-Host (Get-Texto "p_titulo")
if (-not (Test-Path -LiteralPath $smu)) {
  Write-Host (Get-Texto "p_sem_exe" $smu)
  Write-Host (Get-Texto "p_fallback")
  exit 0
}
$texto = ""
$code = 0
try {
  $saida = & $smu --get-pbo-limits 2>&1
  $code = $LASTEXITCODE
  $texto = ($saida | ForEach-Object { "$_" }) -join [Environment]::NewLine
} catch {
  $code = 1
  $texto = $_.Exception.Message
}
if (($code -ne 0) -or [string]::IsNullOrWhiteSpace($texto) -or ($texto -match '(?i)(unrecognized|unknown|invalid|unsupported|not supported)')) {
  Write-Host (Get-Texto "p_nao_suportado")
  Write-Host (Get-Texto "p_fallback")
  exit 0
}
Write-Host $texto
exit 0
