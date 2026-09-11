# Menu principal do ryzen-co-toolkit (PT-BR simples)
# Uso: .\menu.ps1   (sem params; rode 1 vez e siga as opcoes 1 a 7)
$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $PSCommandPath
$root = Split-Path -Parent $ScriptDir
$toolsDir = Join-Path $root "tools"

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-PreFlight {
  if (-not (Test-Admin)) {
    Write-Host "AVISO: voce NAO esta como administrador."
    Write-Host "Algumas opcoes vao pedir permissao (UAC) na hora. Isso e normal."
    Write-Host ""
  }
  if (-not (Test-Path -LiteralPath $toolsDir)) {
    Write-Host "AVISO: pasta tools\ nao encontrada."
    Write-Host "Rode a opcao 1 primeiro (baixa e instala tudo)."
    Write-Host ""
  }
}

Show-PreFlight

do {
  try { if (-not [Console]::IsOutputRedirected) { Clear-Host } } catch {}
  Write-Host "=== Ryzen CO Toolkit - Menu ==="
  Write-Host "1 - Instalar (baixar ferramentas + registrar tarefa elevada)"
  Write-Host "2 - Ver estado atual (offsets + temperatura/consumo)"
  Write-Host "3 - Aplicar ajuste de voltagem por nucleo"
  Write-Host "4 - Testar comparando antes/depois (teste A/B)"
  Write-Host "5 - Checar erros de hardware (WHEA)"
  Write-Host "6 - Ajuste automatico (recomendado para iniciantes)"
  Write-Host "7 - Afinar por nucleo (se a opcao 6 falhou em algum degrau)"
  Write-Host "0 - Sair"
  Write-Host ""
  $opcao = Read-Host "Escolha [0-7]"

  if ($opcao -eq "1") {
    if (-not (Test-Path -LiteralPath $toolsDir)) {
      Write-Host "Baixando ferramentas das fontes oficiais..."
    }
    & (Join-Path $ScriptDir "1-baixar-ferramentas.ps1")
    & (Join-Path $ScriptDir "2-instalar-dispatcher.ps1")
  }
  elseif ($opcao -eq "2") {
    & (Join-Path $ScriptDir "ler-offsets.ps1")
    Write-Host ""
    & (Join-Path $ScriptDir "ler-sensores.ps1")
  }
  elseif ($opcao -eq "3") {
    Write-Host "Ajuste de voltagem por nucleo: valores negativos usam menos"
    Write-Host "voltagem (ex.: -25,-25,-25,-25,-25,-25 para 6 nucleos)."
    $csv = Read-Host "Digite os valores separados por virgula"
    if ([string]::IsNullOrWhiteSpace($csv)) {
      Write-Host "Cancelado: nenhum valor digitado."
    }
    else {
      Write-Host "AVISO: o ajuste e temporario - some se reiniciar ou suspender."
      $conf = Read-Host "Confirmar? (S/N)"
      if ($conf -eq "S" -or $conf -eq "s") {
        & (Join-Path $ScriptDir "aplicar-offsets.ps1") -Offsets $csv
      }
      else {
        Write-Host "Cancelado: nada foi aplicado."
      }
    }
  }
  elseif ($opcao -eq "4") {
    Write-Host "O teste compara o PC antes e depois do ajuste, com carga pesada."
    $offB = Read-Host "Digite o ajuste a testar (Enter = -25,-25,-25,-25,-25,-25)"
    if ([string]::IsNullOrWhiteSpace($offB)) {
      $offB = "-25,-25,-25,-25,-25,-25"
    }
    $segIn = Read-Host "Duracao de cada fase em segundos (Enter = 120)"
    $segundos = 120
    if (-not [string]::IsNullOrWhiteSpace($segIn)) {
      $segundos = [int]$segIn
    }
    Write-Host ("Vai testar o ajuste {0} por {1} segundos por fase." -f $offB, $segundos)
    Write-Host "AVISO: no fim o ajuste testado fica aplicado (temporario - some ao reiniciar)."
    $conf = Read-Host "Confirmar? (S/N)"
    if ($conf -eq "S" -or $conf -eq "s") {
      & (Join-Path $ScriptDir "teste-ab.ps1") -OffsetB $offB -Segundos $segundos
    }
    else {
      Write-Host "Cancelado: nenhum teste foi rodado."
    }
  }
  elseif ($opcao -eq "5") {
    & (Join-Path $ScriptDir "checar-whea.ps1")
  }
  elseif ($opcao -eq "6") {
    & (Join-Path $ScriptDir "auto-tune.ps1")
  }
  elseif ($opcao -eq "7") {
    Write-Host "Valida cada nucleo separado com CoreCycler + Prime95."
    $m = Read-Host "Modo: Rapido (R) ou Completo (C)? (Enter = Rapido)"
    $modo = "Rapido"
    if ($m -eq "C" -or $m -eq "c" -or $m -eq "Completo" -or $m -eq "completo") {
      $modo = "Completo"
    }
    $n = Read-Host "Nucleos (ex.: 0,1,2 ou Enter = todos)"
    if ([string]::IsNullOrWhiteSpace($n)) {
      $n = "all"
    }
    & (Join-Path $ScriptDir "validar-nucleos.ps1") -Modo $modo -Nucleos $n
  }
  elseif ($opcao -eq "0") {
    Write-Host "Ate logo!"
  }
  else {
    Write-Host "Opcao invalida. Digite um numero de 0 a 7."
  }
} until ($opcao -eq "0")
