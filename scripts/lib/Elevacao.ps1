# Elevacao unificada via PBO-Runner (RF-02 / C-02 / RN-03 / RNF-01)
# Dot-sourced pelos 5 scripts que exigem admin. PS 5.1 apenas.
# Uso no chamador (dentro do bloco -not $isAdmin):
#   . (Join-Path $PSScriptRoot "lib\Elevacao.ps1")
#   Invoke-Elevado -ScriptPath $PSCommandPath -Argumentos '-Offsets "-30,-30,-30,-30,-30,-30"'
#   exit
# Fluxo: se a task PBO-Runner existe -> escreve cmd.txt (dentro da allowlist do
# exec.ps1), dispara Start-ScheduledTask e aguarda logs/out.txt com timeout,
# exibindo o conteudo. Senao -> fallback UAC avulso (Start-Process -Verb RunAs)
# com Write-Warning explicito (nunca silenciar).
# NOTA: sem ACL restritiva em cmd.txt/logs — escritor e leitor sao nao-elevados.
$script:ElevacaoLibDir = $PSScriptRoot

function Invoke-Elevado {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [string]$Argumentos = "",
    [int]$TimeoutSeg = 300
  )
  $libDir = $script:ElevacaoLibDir
  if ([string]::IsNullOrEmpty($libDir)) {
    $libDir = Split-Path -Parent $ScriptPath
  }
  $scriptsDir = Split-Path -Parent $libDir
  $root = Split-Path -Parent $scriptsDir
  $cmdFile = Join-Path $root "cmd.txt"
  $outFile = Join-Path $root "logs\out.txt"

  $task = Get-ScheduledTask -TaskName "PBO-Runner" -ErrorAction SilentlyContinue
  if ($null -eq $task) {
    Write-Warning "PBO-Runner ausente, usando UAC avulso"
    $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    if (-not [string]::IsNullOrWhiteSpace($Argumentos)) { $argLine = "$argLine $Argumentos" }
    Start-Process powershell -Verb RunAs -ArgumentList $argLine
    return
  }

  $cmd = "& `"$ScriptPath`""
  if (-not [string]::IsNullOrWhiteSpace($Argumentos)) { $cmd = "$cmd $Argumentos" }
  Set-Content -Path $cmdFile -Value $cmd -Encoding UTF8
  if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile -Force }
  Start-ScheduledTask -TaskName "PBO-Runner"

  $fim = (Get-Date).AddSeconds($TimeoutSeg)
  $plano = $false
  try { $plano = [Console]::IsOutputRedirected } catch { $plano = $false }
  $frames = @("|", "/", "-", "\")
  $fi = 0
  Write-Host "Aguardando PBO-Runner (logs/out.txt)..."
  while ((Get-Date) -lt $fim) {
    Start-Sleep -Seconds 1
    if (Test-Path -LiteralPath $outFile) {
      $parcial = Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue
      if ($null -ne $parcial -and $parcial -match "=== EXIT (OK|FAIL|BLOQUEADO) ===") { break }
    }
    if ($plano) {
      Write-Host ("aguardando PBO-Runner... {0}s" -f $fi)
    } else {
      try {
        $top = [Console]::CursorTop
        [Console]::SetCursorPosition(0, $top)
        Write-Host ("{0} aguardando PBO-Runner... " -f $frames[$fi % 4]) -NoNewline
      } catch {
        Write-Host ("aguardando PBO-Runner... {0}s" -f $fi)
      }
    }
    $fi++
  }
  if (-not $plano) { Write-Host "" }

  if (-not (Test-Path -LiteralPath $outFile)) {
    Write-Host "ERRO: tempo esgotado aguardando o PBO-Runner (logs/out.txt nao criado em ${TimeoutSeg}s)."
    exit 1
  }
  $conteudo = Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue
  if ($conteudo -notmatch "=== EXIT (OK|FAIL|BLOQUEADO) ===") {
    Write-Host "ERRO: tempo esgotado aguardando o PBO-Runner (${TimeoutSeg}s). Conteudo parcial:"
  }
  Write-Host $conteudo
  if ($conteudo -match "=== EXIT BLOQUEADO ===") { exit 1 }
}
