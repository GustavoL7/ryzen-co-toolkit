# 1 - Baixa as ferramentas de terceiros para a pasta tools\
# Nao precisa de admin. Baixa sempre das fontes oficiais (nada e redistribuido aqui).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tools = Join-Path $root "tools"
New-Item -ItemType Directory -Force -Path $tools | Out-Null
Set-Location $tools

function Get-File {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Nome,
    [Parameter(Mandatory = $true)][string]$Sha256
  )
  if (Test-Path $Nome) {
    $atual = (Get-FileHash $Nome -Algorithm SHA256).Hash.ToLower()
    if ($atual -eq $Sha256.ToLower()) { Write-Host "[skip] $Nome ja existe e hash confere"; return }
    Write-Host "[rebaixando] $Nome hash divergente (versao antiga ou corrompido)..."
    Remove-Item -Force $Nome
  }
  Write-Host "[baixando] $Nome ..."
  Invoke-WebRequest -Uri $Url -OutFile $Nome
  $hash = (Get-FileHash $Nome -Algorithm SHA256).Hash.ToLower()
  if ($hash -ne $Sha256.ToLower()) { throw "SHA256 de $Nome difere do esperado! Obtido: $hash Esperado: $Sha256" }
  Write-Host "[hash ok] $Nome"
  Write-Host "[ok] $Nome ($([math]::Round((Get-Item $Nome).Length / 1MB, 1)) MB)"
}

# 7zr (extrator de .7z standalone, 7-zip.org)
# Hash TOFU (sem digest publicado; URL sem versao oficial, mantida a oficial do site)
Get-File -Url "https://www.7-zip.org/a/7zr.exe" -Nome "7zr.exe" -Sha256 "ad4c82fadcbdf93c03b4fc440f300509c7d60c5c2f4d183e35d9d70d6957037d"

# CoreCycler (sp00n) - teste de estabilidade 1-core por vez
# Hash oficial (digest da release v0.11.0.3 no GitHub)
$coreCyclerUrl = "https://github.com/sp00n/CoreCycler/releases/download/v0.11.0.3/CoreCycler-v0.11.0.3.7z"
Get-File -Url $coreCyclerUrl -Nome "CoreCycler.7z" -Sha256 "721ed2948b51a2fc7c60289ecb7cbf62057b22d54c4ba5dc70ac5a107fcc1a63"

if (-not (Test-Path "CoreCycler")) {
  & ".\7zr.exe" x -y "CoreCycler.7z" -o"$tools\CoreCycler" | Out-Null
  Write-Host "[extraido] CoreCycler"
}

# Prime95 (Mersenne, portable) - motor de stress do CoreCycler (modo SSE)
# Hash oficial (digest da release v30.19 b20 no site da Mersenne)
Get-File -Url "https://download.mersenne.ca/gimps/v30/30.19/p95v3019b20.win64.zip" -Nome "p95.zip" -Sha256 "d9475f2ff3f4a6a701abc49a86a66126cb48abd10bda6fa87039d98fa8756bca"
$p95destinos = @((Join-Path $tools "CoreCycler\test_programs\p95"))
$ccAninhado = Join-Path $tools "CoreCycler\CoreCycler-v0.11.0.3\script-corecycler.ps1"
if (Test-Path -LiteralPath $ccAninhado) {
  $p95destinos += (Join-Path $tools "CoreCycler\CoreCycler-v0.11.0.3\test_programs\p95")
}
foreach ($p95dir in $p95destinos) {
  New-Item -ItemType Directory -Force -Path $p95dir | Out-Null
  if (-not (Test-Path (Join-Path $p95dir "prime95.exe"))) {
    Expand-Archive -Path (Join-Path $tools "p95.zip") -DestinationPath $p95dir -Force
    Write-Host "[extraido] Prime95 -> $p95dir"
  } else {
    Write-Host "[skip] Prime95 ja extraido em $p95dir"
  }
}

# ryzen-smu-cli - aplica/lê offsets CO via SMU (Zen 3)
# Hash TOFU (sem digest publicado; URL versionada 0.1.3 mantida, tamanho confere com API)
Get-File -Url "https://github.com/rawhide-kobayashi/ryzen-smu-cli/releases/download/0.1.3/ryzen-smu-cli-0.1.3.zip" -Nome "ryzen-smu-cli.zip" -Sha256 "0131955f780566d43f464350c65de7f929dd9cb57a583c401fe7545712e98ffb"
if (-not (Test-Path "ryzen-smu-cli")) {
  Expand-Archive -Path "ryzen-smu-cli.zip" -DestinationPath "$tools\ryzen-smu-cli" -Force
  Write-Host "[extraido] ryzen-smu-cli"
}

# LibreHardwareMonitor - telemetria (Tctl, PPT, SVI2, clocks)
# Hash oficial (digest da release v0.9.6 no GitHub)
Get-File -Url "https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/download/v0.9.6/LibreHardwareMonitor.zip" -Nome "LibreHardwareMonitor.zip" -Sha256 "086d9f1b5a99e643edc2cfaaac16051685b551e4c5ac0b32a57c58c0e529c001"
if (-not (Test-Path "LibreHardwareMonitor")) {
  Expand-Archive -Path "LibreHardwareMonitor.zip" -DestinationPath "$tools\LibreHardwareMonitor" -Force
  Write-Host "[extraido] LibreHardwareMonitor"
}

# PawnIO - driver kernel (o CoreCycler e o ryzen-smu-cli usam)
# Installer .exe - roda manualmente (precisa de UAC) ou o script 2 avisa
# Hash oficial (digest da release 2.2.0 no GitHub)
Get-File -Url "https://github.com/namazso/PawnIO.Setup/releases/download/2.2.0/PawnIO_setup.exe" -Nome "PawnIO_setup.exe" -Sha256 "1f519a22e47187f70a1379a48ca604981c4fcf694f4e65b734aaa74a9fba3032"

# Nota: se o ryzen-smu-cli reclamar de falta de .NET 8 com apenas .NET 9+ instalado,
# o script ja corrige o runtimeconfig (rollForward LatestMajor). Ver funcao abaixo.
$rc = Join-Path $tools "ryzen-smu-cli\ryzen-smu-cli.runtimeconfig.json"
if (Test-Path $rc) {
  $json = Get-Content $rc -Raw | ConvertFrom-Json
  if (-not $json.runtimeOptions.framework.PSObject.Properties["rollForward"]) {
    $json.runtimeOptions.framework | Add-Member -NotePropertyName "rollForward" -NotePropertyValue "LatestMajor"
    $json | ConvertTo-Json -Depth 5 | Set-Content $rc -Encoding UTF8
    Write-Host "[patch] runtimeconfig: rollForward=LatestMajor (permite rodar com .NET 9+)"
  }
}

Write-Host ""
Write-Host "=== Ferramentas baixadas em $tools ==="
Write-Host "Instale o PawnIO se ainda nao estiver instalado:"
Write-Host "  tools\PawnIO_setup.exe  (UAC - clique em Sim)"
Write-Host "Verifique com: sc query PawnIO"
