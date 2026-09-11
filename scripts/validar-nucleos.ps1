# Valida offsets por nucleo via CoreCycler + Prime95 (SSE, 1 core por vez)
# Uso: .\validar-nucleos.ps1 [-Modo Rapido|Completo] [-Nucleos <csv|"all">]
# Ex.: .\validar-nucleos.ps1 -Modo Rapido -Nucleos "all"
# Ex.: .\validar-nucleos.ps1 -Modo Completo -Nucleos "0,2,5"
# Nao precisa de admin (CoreCycler roda como usuario normal).
# O config.ini original do CoreCycler e restaurado ao final (sempre).
# Textos visiveis via scripts/lib/Idioma.ps1 (default EN).
param(
  [string]$Modo = "",
  [string]$Nucleos = "all"
)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $ScriptDir "lib\Idioma.ps1")
$root = Split-Path -Parent $ScriptDir
$toolsDir = Join-Path $root "tools"
$logsDir = Join-Path $root "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

function Find-CoreCyclerDir {
  $c1 = Join-Path $toolsDir "CoreCycler"
  if (Test-Path -LiteralPath (Join-Path $c1 "script-corecycler.ps1")) { return $c1 }
  $c2 = Join-Path $c1 "CoreCycler-v0.11.0.3"
  if (Test-Path -LiteralPath (Join-Path $c2 "script-corecycler.ps1")) { return $c2 }
  return $null
}

function Get-NumNucleos {
  try {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    if ($cpu.NumberOfCores -gt 0) { return [int]$cpu.NumberOfCores }
  } catch {}
  return 6
}

function Set-IniValor {
  param([string[]]$Linhas, [string]$Secao, [string]$Chave, [string]$Valor)
  $lista = New-Object System.Collections.ArrayList
  foreach ($l in $Linhas) { [void]$lista.Add($l) }
  $idxSecao = -1
  for ($i = 0; $i -lt $lista.Count; $i++) {
    if (([string]$lista[$i]).Trim() -eq "[$Secao]") { $idxSecao = $i; break }
  }
  if ($idxSecao -lt 0) {
    [void]$lista.Add("")
    [void]$lista.Add("[$Secao]")
    [void]$lista.Add("$Chave = $Valor")
    return [string[]]$lista.ToArray()
  }
  $padrao = "^\s*" + [regex]::Escape($Chave) + "\s*="
  for ($i = $idxSecao + 1; $i -lt $lista.Count; $i++) {
    $t = ([string]$lista[$i]).Trim()
    if ($t.StartsWith("[") -and $t.EndsWith("]")) {
      $lista.Insert($i, "$Chave = $Valor")
      return [string[]]$lista.ToArray()
    }
    if ($t -notlike "#*" -and $t -match $padrao) {
      $lista[$i] = "$Chave = $Valor"
      return [string[]]$lista.ToArray()
    }
  }
  [void]$lista.Add("$Chave = $Valor")
  return [string[]]$lista.ToArray()
}

# --- Pre-flight ---
$ccDir = Find-CoreCyclerDir
if ($ccDir -eq $null) {
  Write-Host (Get-Texto "v_cc_falta")
  exit 2
}
$p95exe = Join-Path $ccDir "test_programs\p95\prime95.exe"
if (-not (Test-Path -LiteralPath $p95exe)) {
  Write-Host (Get-Texto "v_p95_falta")
  exit 2
}
$configIni = Join-Path $ccDir "config.ini"
if (-not (Test-Path -LiteralPath $configIni)) {
  Write-Host (Get-Texto "v_cfg_falta")
  exit 2
}

$nFisicos = Get-NumNucleos

# --- Modo (pergunta se nao veio valido) ---
if ($Modo -ne "Rapido" -and $Modo -ne "Completo") {
  Write-Host (Get-Texto "v_modo_rapido")
  Write-Host (Get-Texto "v_modo_completo")
  $m = Read-Host (Get-Texto "v_modo_prompt")
  if (($m -eq "Completo") -or ($m -eq "completo") -or ($m -eq "C") -or ($m -eq "c") -or ($m -eq "Full") -or ($m -eq "full") -or ($m -eq "F") -or ($m -eq "f")) { $Modo = "Completo" }
  else { $Modo = "Rapido" }
}
if ($Modo -eq "Rapido") { $ModoTxt = (Get-Texto "v_nome_rapido") } else { $ModoTxt = (Get-Texto "v_nome_completo") }

# --- Nucleos-alvo ---
$alvos = @()
if ([string]::IsNullOrWhiteSpace($Nucleos) -or $Nucleos -eq "all") {
  for ($i = 0; $i -lt $nFisicos; $i++) { $alvos += $i }
} else {
  foreach ($p in ($Nucleos -split ",")) {
    $t = $p.Trim()
    if ($t -ne "") { $alvos += [int]$t }
  }
}
if ($alvos.Count -eq 0) {
  Write-Host (Get-Texto "v_nucleo_erro")
  exit 1
}

if ($Modo -eq "Rapido") {
  $fft = "Small"
  $runtime = "6m"
  $timeoutSeg = ($alvos.Count * 8 * 60) + 600
  $estimativa = (Get-Texto "v_est_rapido" ($alvos.Count * 6) $alvos.Count)
} else {
  $fft = "All"
  $runtime = "auto"
  $timeoutSeg = ($alvos.Count * 75 * 60) + 1800
  $estimativa = (Get-Texto "v_est_completo" ($alvos.Count * 40) ($alvos.Count * 65) $alvos.Count)
}

# --- Confirmacao S/N (aceita S/s em PT e S/s/Y/y em EN) ---
Write-Host (Get-Texto "v_confirma_linha" $alvos.Count ($alvos -join ",") $ModoTxt $fft)
Write-Host (Get-Texto "v_duracao" $estimativa)
$conf = Read-Host (Get-Texto "g_confirma")
if (($conf -ne "S") -and ($conf -ne "s") -and ($conf -ne "Y") -and ($conf -ne "y")) {
  Write-Host (Get-Texto "v_cancelado")
  exit 0
}

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$resumoLog = Join-Path $logsDir ("validar-nucleos-" + $ts + ".log")

# --- Backup + config gerada (restaurada SEMPRE no finally) ---
$backup = "$configIni.bak-validar-nucleos"
Copy-Item -LiteralPath $configIni -Destination $backup -Force
try {
  [string[]]$linhas = Get-Content -LiteralPath $configIni
  $linhas = Set-IniValor -Linhas $linhas -Secao "General" -Chave "useConfigFile" -Valor ""
  $linhas = Set-IniValor -Linhas $linhas -Secao "General" -Chave "stressTestProgram" -Valor "PRIME95"
  $linhas = Set-IniValor -Linhas $linhas -Secao "General" -Chave "runtimePerCore" -Valor $runtime
  $linhas = Set-IniValor -Linhas $linhas -Secao "General" -Chave "stopOnError" -Valor "0"
  $linhas = Set-IniValor -Linhas $linhas -Secao "General" -Chave "skipCoreOnError" -Valor "1"
  if ($Nucleos -ne "all" -and -not [string]::IsNullOrWhiteSpace($Nucleos)) {
    $linhas = Set-IniValor -Linhas $linhas -Secao "General" -Chave "coreTestOrder" -Valor (($alvos | ForEach-Object { "$_" }) -join ", ")
  }
  $linhas = Set-IniValor -Linhas $linhas -Secao "Prime95" -Chave "mode" -Valor "SSE"
  $linhas = Set-IniValor -Linhas $linhas -Secao "Prime95" -Chave "FFTSize" -Valor $fft
  $linhas | Set-Content -LiteralPath $configIni -Encoding UTF8
  Write-Host (Get-Texto "v_config" $fft $runtime)

  # --- Roda o launcher e aguarda com poll ---
  $launcher = Join-Path $ccDir "script-corecycler.ps1"
  Write-Host (Get-Texto "v_iniciando")
  $proc = Start-Process -FilePath "powershell.exe" -ArgumentList ("-ExecutionPolicy Bypass -NoProfile -File `"{0}`"" -f $launcher) -WorkingDirectory $ccDir -PassThru
  $limite = (Get-Date).AddSeconds($timeoutSeg)
  while (-not $proc.HasExited) {
    Start-Sleep -Seconds 30
    if ((Get-Date) -gt $limite) {
      Write-Warning (Get-Texto "v_timeout")
      try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
      break
    }
    $faltaMin = [math]::Max(0, [int](New-TimeSpan -Start (Get-Date) -End $limite).TotalMinutes)
    Write-Host (Get-Texto "v_aguardando" $faltaMin)
  }
  Write-Host (Get-Texto "v_fim" $proc.ExitCode)

  # --- Parseia o log mais novo: ultimo "Set to Core X" antes do erro = culpado ---
  $ccLogs = Join-Path $ccDir "logs"
  $logCc = Get-ChildItem -LiteralPath $ccLogs -Filter "CoreCycler_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $testados = @()
  $falhas = @{}
  if ($logCc -ne $null) {
    foreach ($linha in (Get-Content -LiteralPath $logCc.FullName)) {
      if ($linha -match "Set to Core\s+(\d+)") {
        $nuc = [int]$Matches[1]
        if (-not ($testados -contains $nuc)) { $testados += $nuc }
      }
      if ($linha -match "FATAL ERROR|Hardware failure|WHEA") {
        if ($testados.Count -gt 0) { $falhas[$testados[$testados.Count - 1]] = $linha.Trim() }
      }
    }
  }

  # --- Relatorio ---
  $relatorio = @()
  $relatorio += (Get-Texto "v_rel_cab" $ts $ModoTxt $fft $runtime ($alvos -join ","))
  if ($logCc -ne $null) { $relatorio += (Get-Texto "v_rel_log" $logCc.FullName) }
  $ordem = @($testados | Sort-Object)
  if ($ordem.Count -eq 0) {
    $relatorio += (Get-Texto "v_rel_aviso")
    $ordem = $alvos | Sort-Object
  }
  foreach ($c in $ordem) {
    if ($falhas.ContainsKey($c)) { $relatorio += (Get-Texto "v_nucleo_fail" $c) }
    else { $relatorio += (Get-Texto "v_nucleo_pass" $c) }
  }
  $ruins = @($falhas.Keys | Sort-Object)
  if ($ruins.Count -gt 0) {
    $relatorio += (Get-Texto "v_sugestao" ($ruins -join ", "))
  } else {
    $relatorio += (Get-Texto "v_sem_falha" $ModoTxt)
  }
  foreach ($r in $relatorio) { Write-Host $r }
  $relatorio | Set-Content -LiteralPath $resumoLog -Encoding UTF8
  Write-Host (Get-Texto "v_resumo" $resumoLog)
} finally {
  Copy-Item -LiteralPath $backup -Destination $configIni -Force
  Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
  Write-Host (Get-Texto "v_restaurado")
}
