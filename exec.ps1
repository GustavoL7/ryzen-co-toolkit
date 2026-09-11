# Dispatcher: executa o comando em cmd.txt com privilegios de administrador
# (via Task Scheduler "PBO-Runner") e grava a saida em logs\out.txt
# Endurecido (RF-01 / C-01 / RN-02 / RNF-04): allowlist DENY-by-default (regex
# ancoradas ^...$), 1 linha em cmd.txt, sem [scriptblock]::Create aberto
# (invocacao restrita via operador &), saida S-01.
# NOTA: sem ACL-stripping aqui — o fluxo exige escritor de cmd.txt e leitor de
# logs/out.txt NAO-elevados (mesmo usuario interativo); a garantia e a
# validacao de conteudo (allowlist + 1 linha + deny-chars + path confinado ao $root).
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$cmdFile = Join-Path $root "cmd.txt"
$logsDir = Join-Path $root "logs"
$outFile = Join-Path $logsDir "out.txt"

if (-not (Test-Path -LiteralPath $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }

function Split-Args {
  param([string]$s)
  $list = New-Object System.Collections.ArrayList
  $cur = ""
  $inQ = $false
  $i = 0
  while ($i -lt $s.Length) {
    $ch = $s[$i]
    if ($ch -eq '"') {
      $inQ = -not $inQ
    } elseif (($ch -eq ' ' -or $ch -eq "`t") -and (-not $inQ)) {
      if ($cur.Length -gt 0) { [void]$list.Add($cur); $cur = "" }
    } else {
      $cur += $ch
    }
    $i++
  }
  if ($cur.Length -gt 0) { [void]$list.Add($cur) }
  return ,$list.ToArray()
}

function Write-Blocked {
  param([string]$Motivo)
  "BLOQUEADO: $Motivo" | Out-File $outFile -Append
  "=== EXIT BLOQUEADO ===" | Out-File $outFile -Append
  exit 1
}

"=== EXEC $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $outFile
try {
  if (-not (Test-Path -LiteralPath $cmdFile)) { Write-Blocked "cmd.txt ausente" }
  $rawLines = @(Get-Content -LiteralPath $cmdFile -Encoding UTF8)
  $cmds = @($rawLines | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne "" })
  if ($cmds.Count -eq 0) { Write-Blocked "cmd.txt vazio" }
  if ($cmds.Count -gt 1) { Write-Blocked "mais de 1 linha em cmd.txt (esperado 1 comando)" }
  $cmd = $cmds[0]

  $denyChars = '[;|`$]'
  if ($cmd -match $denyChars) { Write-Blocked "caracteres/operadores proibidos (comando fora da allowlist)" }
  if ($cmd -match '(?i)\b(invoke-expression|invoke-command|scriptblock|add-type|new-object|start-process|stop-process|remove-item|set-content|start-job)\b') { Write-Blocked "construcao proibida (comando fora da allowlist)" }

  $allowTerse  = '^(?:&\s*)?"?[^"\s]*ryzen-smu-cli(\.exe)?"?\s+--get-offsets-terse\s*$'
  $allowScalar = '^(?:&\s*)?"?[^"\s]*ryzen-smu-cli(\.exe)?"?\s+--get-pbo-scalar\s*$'
  $allowOffset = '^(?:&\s*)?"?[^"\s]*ryzen-smu-cli(\.exe)?"?\s+--offset\s+-?\d+(,-?\d+){0,15}\s*$'
  $allowPs1    = '^(?:&\s*)?"(?<ps1>[^"]*\\scripts\\(?:aplicar-offsets|ler-offsets|ler-sensores|teste-ab|checar-whea|1-baixar-ferramentas)\.ps1)"(?<args>(?:\s+-[A-Za-z]+\s+(?:"[^"]*"|[^\s"]+))*)\s*$'

  if ($cmd -match $allowTerse) {
    $exePath = $null
    if ($cmd -match '"(?<p>[^"]+)"') { $exePath = $Matches.p } else { $exePath = ($cmd -replace '^&\s*', '').Split(' ')[0] }
    if ($exePath -notmatch '[\\/]') { $exePath = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe" }
    else {
      if (-not [IO.Path]::IsPathRooted($exePath)) { $exePath = Join-Path $root $exePath }
      $full = [IO.Path]::GetFullPath($exePath)
      if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { Write-Blocked "caminho do executavel fora do kit (comando fora da allowlist)" }
      $exePath = $full
    }
    & $exePath --get-offsets-terse *>&1 | Out-File $outFile -Append
  } elseif ($cmd -match $allowScalar) {
    $exePath = $null
    if ($cmd -match '"(?<p>[^"]+)"') { $exePath = $Matches.p } else { $exePath = ($cmd -replace '^&\s*', '').Split(' ')[0] }
    if ($exePath -notmatch '[\\/]') { $exePath = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe" }
    else {
      if (-not [IO.Path]::IsPathRooted($exePath)) { $exePath = Join-Path $root $exePath }
      $full = [IO.Path]::GetFullPath($exePath)
      if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { Write-Blocked "caminho do executavel fora do kit (comando fora da allowlist)" }
      $exePath = $full
    }
    & $exePath --get-pbo-scalar *>&1 | Out-File $outFile -Append
  } elseif ($cmd -match $allowOffset) {
    $csv = $null
    [void]($cmd -match '--offset\s+(?<csv>-?\d+(?:,-?\d+){0,15})\s*$')
    $csv = $Matches.csv
    $exePath = $null
    if ($cmd -match '"(?<p>[^"]+)"') { $exePath = $Matches.p } else { $exePath = ($cmd -replace '^&\s*', '').Split(' ')[0] }
    if ($exePath -notmatch '[\\/]') { $exePath = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe" }
    else {
      if (-not [IO.Path]::IsPathRooted($exePath)) { $exePath = Join-Path $root $exePath }
      $full = [IO.Path]::GetFullPath($exePath)
      if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { Write-Blocked "caminho do executavel fora do kit (comando fora da allowlist)" }
      $exePath = $full
    }
    & $exePath --offset $csv *>&1 | Out-File $outFile -Append
  } elseif ($cmd -match $allowPs1) {
    $ps1 = $Matches.ps1
    $argStr = $Matches.args
    if (-not [IO.Path]::IsPathRooted($ps1)) { $ps1 = Join-Path $root $ps1 }
    $full = [IO.Path]::GetFullPath($ps1)
    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { Write-Blocked "script fora do kit (comando fora da allowlist)" }
    if (-not (Test-Path -LiteralPath $full)) { Write-Blocked "script interno nao encontrado (comando fora da allowlist)" }
    $argArr = Split-Args "$argStr"
    & $full @argArr *>&1 | Out-File $outFile -Append
  } else {
    Write-Blocked "comando fora da allowlist"
  }
  if ($?) { "=== EXIT OK ===" | Out-File $outFile -Append } else { "=== EXIT FAIL ===" | Out-File $outFile -Append }
  if ($?) { exit 0 } else { exit 1 }
} catch {
  "ERRO: $($_.Exception.Message)" | Out-File $outFile -Append
  "=== EXIT FAIL ===" | Out-File $outFile -Append
  exit 1
}
