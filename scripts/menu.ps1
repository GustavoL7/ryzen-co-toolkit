# Menu principal do ryzen-co-toolkit (textos via scripts/lib/Idioma.ps1, default EN)
# Uso: .\menu.ps1   (sem params; rode 1 vez e siga as opcoes 1 a 8)
$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $ScriptDir "lib\Idioma.ps1")
$root = Split-Path -Parent $ScriptDir
$toolsDir = Join-Path $root "tools"

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-PreFlight {
  if (-not (Test-Admin)) {
    Write-Host (Get-Texto "m_admin1")
    Write-Host (Get-Texto "m_admin2")
    Write-Host ""
  }
  if (-not (Test-Path -LiteralPath $toolsDir)) {
    Write-Host (Get-Texto "m_tools1")
    Write-Host (Get-Texto "m_tools2")
    Write-Host ""
  }
}

Show-PreFlight

do {
  try { if (-not [Console]::IsOutputRedirected) { Clear-Host } } catch {}
  Write-Host (Get-Texto "m_titulo")
  Write-Host (Get-Texto "m_op1")
  Write-Host (Get-Texto "m_op2")
  Write-Host (Get-Texto "m_op3")
  Write-Host (Get-Texto "m_op4")
  Write-Host (Get-Texto "m_op5")
  Write-Host (Get-Texto "m_op6")
  Write-Host (Get-Texto "m_op7")
  Write-Host (Get-Texto "m_op8")
  Write-Host (Get-Texto "m_op0")
  Write-Host ""
  $opcao = Read-Host (Get-Texto "m_prompt")

  if ($opcao -eq "1") {
    if (-not (Test-Path -LiteralPath $toolsDir)) {
      Write-Host (Get-Texto "m_baixando")
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
    Write-Host (Get-Texto "m_opt3_l1")
    Write-Host (Get-Texto "m_opt3_l2")
    $csv = Read-Host (Get-Texto "m_opt3_prompt")
    if ([string]::IsNullOrWhiteSpace($csv)) {
      Write-Host (Get-Texto "m_opt3_vazio")
    }
    else {
      Write-Host (Get-Texto "g_aviso_temp")
      $conf = Read-Host (Get-Texto "g_confirma")
      if (($conf -eq "S") -or ($conf -eq "s") -or ($conf -eq "Y") -or ($conf -eq "y")) {
        & (Join-Path $ScriptDir "aplicar-offsets.ps1") -Offsets $csv
      }
      else {
        Write-Host (Get-Texto "g_cancel_nada")
      }
    }
  }
  elseif ($opcao -eq "4") {
    Write-Host (Get-Texto "m_opt4_l1")
    $offB = Read-Host (Get-Texto "m_opt4_prompt_off")
    if ([string]::IsNullOrWhiteSpace($offB)) {
      $offB = "-25,-25,-25,-25,-25,-25"
    }
    $segIn = Read-Host (Get-Texto "m_opt4_prompt_seg")
    $segundos = 120
    if (-not [string]::IsNullOrWhiteSpace($segIn)) {
      $segundos = [int]$segIn
    }
    Write-Host (Get-Texto "m_opt4_plano" $offB $segundos)
    Write-Host (Get-Texto "m_opt4_aviso")
    $conf = Read-Host (Get-Texto "g_confirma")
    if (($conf -eq "S") -or ($conf -eq "s") -or ($conf -eq "Y") -or ($conf -eq "y")) {
      & (Join-Path $ScriptDir "teste-ab.ps1") -OffsetB $offB -Segundos $segundos
    }
    else {
      Write-Host (Get-Texto "m_cancel_teste")
    }
  }
  elseif ($opcao -eq "5") {
    & (Join-Path $ScriptDir "checar-whea.ps1")
  }
  elseif ($opcao -eq "6") {
    & (Join-Path $ScriptDir "auto-tune.ps1")
  }
  elseif ($opcao -eq "7") {
    Write-Host (Get-Texto "m_opt7_l1")
    $m = Read-Host (Get-Texto "m_opt7_modo")
    $modo = "Rapido"
    if (($m -eq "C") -or ($m -eq "c") -or ($m -eq "Completo") -or ($m -eq "completo") -or ($m -eq "F") -or ($m -eq "f") -or ($m -eq "Full") -or ($m -eq "full")) {
      $modo = "Completo"
    }
    $n = Read-Host (Get-Texto "m_opt7_nucleos")
    if ([string]::IsNullOrWhiteSpace($n)) {
      $n = "all"
    }
    & (Join-Path $ScriptDir "validar-nucleos.ps1") -Modo $modo -Nucleos $n
  }
  elseif ($opcao -eq "8") {
    if ((Get-Idioma) -eq "pt") {
      Set-Idioma -Codigo "en"
      Write-Host (Get-Texto "m_lang_en")
    }
    else {
      Set-Idioma -Codigo "pt"
      Write-Host (Get-Texto "m_lang_pt")
    }
  }
  elseif ($opcao -eq "0") {
    Write-Host (Get-Texto "m_ate_logo")
  }
  else {
    Write-Host (Get-Texto "m_invalida")
  }
} until ($opcao -eq "0")
