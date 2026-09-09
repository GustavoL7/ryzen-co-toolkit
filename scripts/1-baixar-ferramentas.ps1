# 1 - Baixa as ferramentas de terceiros para a pasta tools\
# Nao precisa de admin. Baixa sempre das fontes oficiais (nada e redistribuido aqui).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tools = Join-Path $root "tools"
New-Item -ItemType Directory -Force -Path $tools | Out-Null
Set-Location $tools

function Get-File($url, $name) {
  if (Test-Path $name) { Write-Host "[skip] $name ja existe"; return }
  Write-Host "[baixando] $name ..."
  Invoke-WebRequest -Uri $url -OutFile $name
  Write-Host "[ok] $name ($([math]::Round((Get-Item $name).Length / 1MB, 1)) MB)"
}

# 7zr (extrator de .7z standalone, 7-zip.org)
Get-File "https://www.7-zip.org/a/7zr.exe" "7zr.exe"

# CoreCycler (sp00n) - teste de estabilidade 1-core por vez
# SHA256 da release v0.11.0.3 oficial
$coreCyclerUrl = "https://github.com/sp00n/CoreCycler/releases/download/v0.11.0.3/CoreCycler-v0.11.0.3.7z"
Get-File $coreCyclerUrl "CoreCycler.7z"
$hash = (Get-FileHash "CoreCycler.7z" -Algorithm SHA256).Hash.ToLower()
$esperado = "721ed2948b51a2fc7c60289ecb7cbf62057b22d54c4ba5dc70ac5a107fcc1a63"
if ($hash -ne $esperado) { throw "SHA256 do CoreCycler difere do esperado! Hash: $hash" }
Write-Host "[hash ok] CoreCycler.7z"

if (-not (Test-Path "CoreCycler")) {
  & ".\7zr.exe" x -y "CoreCycler.7z" -o"$tools\CoreCycler" | Out-Null
  Write-Host "[extraido] CoreCycler"
}

# ryzen-smu-cli - aplica/lê offsets CO via SMU (Zen 3)
Get-File "https://github.com/rawhide-kobayashi/ryzen-smu-cli/releases/download/0.1.3/ryzen-smu-cli-0.1.3.zip" "ryzen-smu-cli.zip"
if (-not (Test-Path "ryzen-smu-cli")) {
  Expand-Archive -Path "ryzen-smu-cli.zip" -DestinationPath "$tools\ryzen-smu-cli" -Force
  Write-Host "[extraido] ryzen-smu-cli"
}

# LibreHardwareMonitor - telemetria (Tctl, PPT, SVI2, clocks)
Get-File "https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/latest/download/LibreHardwareMonitor.zip" "LibreHardwareMonitor.zip"
if (-not (Test-Path "LibreHardwareMonitor")) {
  Expand-Archive -Path "LibreHardwareMonitor.zip" -DestinationPath "$tools\LibreHardwareMonitor" -Force
  Write-Host "[extraido] LibreHardwareMonitor"
}

# PawnIO - driver kernel (o CoreCycler e o ryzen-smu-cli usam)
# Installer .exe - roda manualmente (precisa de UAC) ou o script 2 avisa
Get-File "https://github.com/namazso/PawnIO.Setup/releases/latest/download/PawnIO_setup.exe" "PawnIO_setup.exe"

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
