# Dispatcher: executa o comando em cmd.txt com privilegios de administrador
# (via Task Scheduler "PBO-Runner") e grava a saida em logs\out.txt
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$cmdFile = Join-Path $root "cmd.txt"
$outFile = Join-Path $root "logs\out.txt"

if (-not (Test-Path (Join-Path $root "logs"))) { New-Item -ItemType Directory -Path (Join-Path $root "logs") -Force | Out-Null }

"=== EXEC $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $outFile
try {
  $raw = Get-Content $cmdFile -Raw
  $sb = [scriptblock]::Create($raw)
  Invoke-Command -ScriptBlock $sb *>&1 | Out-File $outFile -Append
  "=== EXIT OK ===" | Out-File $outFile -Append
} catch {
  "ERRO: $($_.Exception.Message)" | Out-File $outFile -Append
  "=== EXIT FAIL ===" | Out-File $outFile -Append
}
