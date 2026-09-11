# Ajuste automatico all-core (recomendado para iniciantes)
# Passada grossa de -Inicio ate -Maximo (passo -Passo) + refino unico apos FAIL.
# Cada degrau aplica o offset, roda carga curta, mede 4 gates e da veredito
# PASS / MARGINAL (re-teste) / FAIL. Monotonicidade assumida: degrau mais fundo
# que um FAIL nunca e tentado (se -20 falha, -30 nao e testado; so o refino).
# Uso: .\auto-tune.ps1 [-Inicio 10] [-Passo 10] [-Maximo 30] [-Segundos 60] [-Refino 5]
# No fim imprime MELHOR/BEST: -<N> all-core — grave esse valor na BIOS.
# Textos visiveis via scripts/lib/Idioma.ps1 (default EN).
param(
  [int]$Inicio = 10,
  [int]$Passo = 10,
  [int]$Maximo = 30,
  [int]$Segundos = 60,
  [int]$Refino = 5
)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "lib\Idioma.ps1")
$aplicar = Join-Path $PSScriptRoot "aplicar-offsets.ps1"
$smu = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe"
$dll = Join-Path $root "tools\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"
$logDir = Join-Path $root "logs"
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$script:logFile = Join-Path $logDir ("auto-tune-" + $ts + ".log")

function Write-Log {
  param([string]$Message)
  Write-Host $Message
  try { Add-Content -LiteralPath $script:logFile -Value $Message -Encoding UTF8 } catch {}
}

# UI fixa (RF-09 / C-07): Write-Tela = SOMENTE console (nunca grava no log).
# Write-Log continua console+arquivo e nao muda. Se output redirecionado,
# tudo vira Write-Host plano (sem Clear-Host/cursor). PS 5.1 apenas.
$script:UiPlana = $false
try { $script:UiPlana = [Console]::IsOutputRedirected } catch { $script:UiPlana = $false }
$script:degrauIndice = 0
$script:degrauTotal = 0
if ($null -eq $script:melhorStretch) { $script:melhorStretch = 0 }

function Write-Tela {
  param([string]$Message = "")
  Write-Host $Message
}

function Show-PainelDegrau {
  param([int]$Mag, [string]$Csv, [switch]$EhRefino)
  if ($script:UiPlana) {
    if ($EhRefino) {
      Write-Tela ""
      Write-Tela (Get-Texto "a_painel_refino_cab" $Mag $Csv)
    } else {
      Write-Tela ""
      Write-Tela (Get-Texto "a_painel_degrau_cab" $Mag $Csv $script:degrauIndice $script:degrauTotal)
    }
    return
  }
  Clear-Host
  Write-Tela (Get-Texto "a_painel_titulo")
  if ($EhRefino) {
    Write-Tela (Get-Texto "a_painel_refino_linha" $Mag)
  } else {
    Write-Tela (Get-Texto "a_painel_degrau_linha" $script:degrauIndice $script:degrauTotal $Mag)
  }
  Write-Tela (Get-Texto "a_painel_offset" $Csv)
  if ($script:melhorStretch -gt 0) {
    Write-Tela (Get-Texto "a_painel_melhor" ([math]::Round($script:melhorStretch * 100,1)))
  } else {
    Write-Tela (Get-Texto "a_painel_melhor_nenhum")
  }
  Write-Tela ""
}

function Show-BarraBurn {
  param([int]$Elapsed, [int]$Total)
  if ($Total -le 0) { $Total = 1 }
  if ($Elapsed -lt 0) { $Elapsed = 0 }
  if ($Elapsed -gt $Total) { $Elapsed = $Total }
  $pct = [math]::Floor($Elapsed * 100 / $Total)
  $cheios = [math]::Floor($Elapsed * 10 / $Total)
  if ($cheios -gt 10) { $cheios = 10 }
  $barra = ("#" * $cheios) + ("-" * (10 - $cheios))
  $txt = ("{0} {1}% ({2}/{3}s)" -f $barra, $pct, $Elapsed, $Total)
  if ($script:UiPlana) {
    Write-Tela $txt
    return
  }
  try {
    $top = [Console]::CursorTop
    [Console]::SetCursorPosition(0, $top)
    Write-Host ($txt + " ") -NoNewline
  } catch {
    Write-Host $txt
  }
}

function Show-SpinnerLinha {
  param([string]$Texto, [int]$Indice)
  $frames = @("|", "/", "-", "\")
  $f = $frames[$Indice % 4]
  $txt = ("{0} {1}" -f $f, $Texto)
  if ($script:UiPlana) {
    Write-Tela $txt
    return
  }
  try {
    $top = [Console]::CursorTop
    [Console]::SetCursorPosition(0, $top)
    Write-Host ($txt + "   ") -NoNewline
  } catch {
    Write-Host $txt
  }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  . (Join-Path $PSScriptRoot "lib\Elevacao.ps1")
  Invoke-Elevado -ScriptPath $PSCommandPath -Argumentos "-Inicio $Inicio -Passo $Passo -Maximo $Maximo -Segundos $Segundos -Refino $Refino"
  exit
}

if (-not (Test-Path -LiteralPath $dll)) {
  Write-Log (Get-Texto "a_dll_erro" $dll)
  exit 1
}
Add-Type -Path $dll

$N = 6
try {
  $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
  if ($cpu.NumberOfCores -gt 0) { $N = $cpu.NumberOfCores }
} catch {}
$Threads = $N * 2
try {
  # Burn precisa ocupar TODAS as threads logicas: com threads ociosas, o
  # "Average Effective" medio dilui (ex.: 6/12 threads => ~55% do requested)
  # e o gate de 97% reprova chip saudavel (falso-positivo visto em -5).
  $logi = (Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1).NumberOfLogicalProcessors
  if ($logi -gt 0) { $Threads = $logi }
} catch {}
$TimeoutSeg = $Segundos + 60

function Burn {
  param([int]$seconds, [int]$ThreadCount)
  $sb = { param($s) $end = (Get-Date).AddSeconds($s); $x = 1.234567; while ((Get-Date) -lt $end) { for ($k = 0; $k -lt 3000; $k++) { $x = [math]::Sqrt($x * 1.000001 + $k * 0.0000001) + 0.0000001; $x = [math]::Sin($x) + [math]::Cos($x) + 2.0 } } }
  $list = @()
  for ($i = 1; $i -le $ThreadCount; $i++) { $list += Start-Job -ScriptBlock $sb -ArgumentList $seconds }
  return $list
}

function Stop-Burn {
  param($Jobs)
  if ($null -eq $Jobs) { return }
  foreach ($j in $Jobs) { try { Stop-Job -Job $j -ErrorAction SilentlyContinue } catch {} }
  foreach ($j in $Jobs) { try { Remove-Job -Job $j -Force -ErrorAction SilentlyContinue } catch {} }
}

function Read-Telemetria {
  $c = New-Object LibreHardwareMonitor.Hardware.Computer
  $c.IsCpuEnabled = $true
  $c.Open() | Out-Null
  Start-Sleep -Seconds 2
  $out = $null
  foreach ($hw in $c.Hardware) {
    if ($hw.HardwareType -eq "Cpu") {
      $hw.Update() | Out-Null
      $temp = ($hw.Sensors | Where-Object { $_.SensorType -eq "Temperature" -and $_.Name -match "Tctl" }).Value
      $pwr  = ($hw.Sensors | Where-Object { $_.SensorType -eq "Power" -and $_.Name -eq "Package" }).Value
      $clk  = ($hw.Sensors | Where-Object { $_.SensorType -eq "Clock" -and $_.Name -eq "Cores (Average)" }).Value
      $eff  = ($hw.Sensors | Where-Object { $_.SensorType -eq "Clock" -and $_.Name -eq "Cores (Average Effective)" }).Value
      if (($null -ne $temp) -and ($null -ne $pwr) -and ($null -ne $clk) -and ($null -ne $eff) -and ($clk -gt 0)) {
        $out = @{ Tctl = $temp; Ppt = $pwr; Clk = $clk; Eff = $eff }
      }
    }
  }
  $c.Close() | Out-Null
  return $out
}

function Get-WheaDesde {
  param($Desde)
  $w = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$Desde} -ErrorAction SilentlyContinue
  if ($null -eq $w) { return @() }
  return @($w)
}

function Test-DegrauMag {
  param([int]$Mag, [switch]$EhRefino)
  $csv = ((1..$N | ForEach-Object { "-$Mag" }) -join ",")
  if ($EhRefino) {
    Show-PainelDegrau -Mag $Mag -Csv $csv -EhRefino
  } else {
    $script:degrauIndice++
    Show-PainelDegrau -Mag $Mag -Csv $csv
  }
  Write-Log ""
  Write-Log (Get-Texto "a_log_degrau" $Mag $csv)
  try {
    $ap = (& $aplicar -Offsets $csv 2>&1 | Out-String)
    Write-Log $ap
  } catch {
    return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_erro_aplicar" $_.Exception.Message); Stretch = 0; Clk = 0; Marginal = $false }
  }

  $t0 = Get-Date
  $failMotivo = ""
  $tel = $null
  try {
    $jobs = Burn -seconds $Segundos -ThreadCount $Threads
  } catch {
    $failMotivo = (Get-Texto "a_burn_falha" $_.Exception.Message)
    $jobs = $null
  }
  if ([string]::IsNullOrEmpty($failMotivo)) {
    $half = [math]::Floor($Segundos / 2)
    $pontoMedicao = $half + 5
    $telMedida = $false
    $burnInicio = Get-Date
    $spin = 0
    Write-Tela ""
    while ($true) {
      Start-Sleep -Seconds 1
      $elapsed = [int]((Get-Date) - $burnInicio).TotalSeconds
      Show-BarraBurn -Elapsed $elapsed -Total $Segundos
      if ((-not $telMedida) -and ($elapsed -ge $pontoMedicao)) {
        Write-Tela ""
        Show-SpinnerLinha -Texto (Get-Texto "a_medindo") -Indice $spin
        $tel = Read-Telemetria
        $telMedida = $true
        Write-Tela ""
      }
      $chk = @($jobs | Where-Object { $_.State -eq "Running" })
      if ($chk.Count -eq 0 -and $telMedida) { break }
      if (((Get-Date) - $burnInicio).TotalSeconds -ge $TimeoutSeg) { break }
      $spin++
    }
    if (-not $telMedida) {
      Show-SpinnerLinha -Texto (Get-Texto "a_medindo") -Indice $spin
      $tel = Read-Telemetria
      $telMedida = $true
    }
    Write-Tela ""
    $null = Wait-Job -Job $jobs -Timeout 5
    $still = @($jobs | Where-Object { $_.State -eq "Running" })
    if ($still.Count -gt 0) {
      Stop-Burn -Jobs $jobs
      $failMotivo = (Get-Texto "a_carga_travou")
    } else {
      $crashed = @($jobs | Where-Object { $_.State -eq "Failed" })
      if ($crashed.Count -gt 0) { $failMotivo = (Get-Texto "a_carga_crash") }
    }
    Stop-Burn -Jobs $jobs
  }

  if (-not [string]::IsNullOrEmpty($failMotivo)) {
    return @{ Veredito = "FAIL"; Motivo = $failMotivo; Stretch = 0; Clk = 0; Marginal = $false }
  }
  if ($null -eq $tel) {
    return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_sensores"); Stretch = 0; Clk = 0; Marginal = $false }
  }
  $stretch = $tel.Eff / $tel.Clk
  Write-Log (Get-Texto "a_medido" ([math]::Round($tel.Tctl,1)) ([math]::Round($tel.Ppt,1)) ([math]::Round($tel.Clk,0)) ([math]::Round($tel.Eff,0)) ([math]::Round($stretch * 100,1)))
  if ($tel.Tctl -gt 90) {
    return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_tctl" ([math]::Round($tel.Tctl,1))); Stretch = $stretch; Clk = $tel.Clk; Marginal = $false }
  }
  if ($stretch -lt 0.80) {
    # Piso absoluto: sob PPT-limit o chip saudavel fica ~88%; abaixo de 80%
    # e stretching claro (gate antigo de 97% reprovava chip saudavel).
    return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_stretch_severo" ([math]::Round($tel.Eff,0)) ([math]::Round($stretch * 100,1)) ([math]::Round($tel.Clk,0))); Stretch = $stretch; Clk = $tel.Clk; Marginal = $false }
  }
  if (($script:melhorStretch -gt 0) -and ($stretch -lt ($script:melhorStretch - 0.08))) {
    # Degradacao relativa: caiu 8pp+ vs melhor degrau do sweep = CO agressivo demais.
    return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_stretch_degrada" ([math]::Round($stretch * 100,1)) ([math]::Round($script:melhorStretch * 100,1))); Stretch = $stretch; Clk = $tel.Clk; Marginal = $false }
  }
  $novos = $null
  Show-SpinnerLinha -Texto (Get-Texto "a_whea") -Indice 0
  $novos = Get-WheaDesde -Desde $t0
  Write-Tela ""
  if ($novos.Count -gt 0) {
    $novos | ForEach-Object { Write-Log (Get-Texto "a_whea_linha" $_.TimeCreated $_.Id) }
    return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_whea_novos" $novos.Count); Stretch = $stretch; Clk = $tel.Clk; Marginal = $false }
  }
  if ($stretch -ge 0.95) {
    return @{ Veredito = "PASS"; Motivo = ""; Stretch = $stretch; Clk = $tel.Clk; Marginal = $false }
  }

  # Faixa 80-95%: MARGINAL -> re-teste imediato (1 burn novo + 2 amostras,
  # mediana das 3 contando a primeira; mediana >= 95% = PASS, senao FAIL).
  Write-Log (Get-Texto "a_marginal" $Mag ([math]::Round($stretch * 100,1)))
  $tR = Get-Date
  $failR = ""
  $tel2 = $null
  $tel3 = $null
  try {
    $jobsR = Burn -seconds $Segundos -ThreadCount $Threads
  } catch {
    $failR = (Get-Texto "a_r_burn" $_.Exception.Message)
    $jobsR = $null
  }
  if ([string]::IsNullOrEmpty($failR)) {
    $terco = [math]::Floor($Segundos / 3)
    if ($terco -lt 5) { $terco = 5 }
    $ponto2 = $terco + 5
    $ponto3 = 2 * $terco + 5
    $fez2 = $false
    $fez3 = $false
    $burnInicioR = Get-Date
    $spinR = 0
    Write-Tela ""
    while ($true) {
      Start-Sleep -Seconds 1
      $elapsedR = [int]((Get-Date) - $burnInicioR).TotalSeconds
      Show-BarraBurn -Elapsed $elapsedR -Total $Segundos
      if ((-not $fez2) -and ($elapsedR -ge $ponto2)) {
        Write-Tela ""
        Show-SpinnerLinha -Texto (Get-Texto "a_medindo_r1") -Indice $spinR
        $tel2 = Read-Telemetria
        $fez2 = $true
        Write-Tela ""
      }
      if ($fez2 -and (-not $fez3) -and ($elapsedR -ge $ponto3)) {
        Write-Tela ""
        Show-SpinnerLinha -Texto (Get-Texto "a_medindo_r2") -Indice $spinR
        $tel3 = Read-Telemetria
        $fez3 = $true
        Write-Tela ""
      }
      $chkR = @($jobsR | Where-Object { $_.State -eq "Running" })
      if (($chkR.Count -eq 0) -and $fez2 -and $fez3) { break }
      if (((Get-Date) - $burnInicioR).TotalSeconds -ge $TimeoutSeg) { break }
      $spinR++
    }
    if (-not $fez2) {
      Show-SpinnerLinha -Texto (Get-Texto "a_medindo_r1") -Indice $spinR
      $tel2 = Read-Telemetria
      $fez2 = $true
    }
    if (-not $fez3) {
      Show-SpinnerLinha -Texto (Get-Texto "a_medindo_r2") -Indice ($spinR + 1)
      $tel3 = Read-Telemetria
      $fez3 = $true
    }
    Write-Tela ""
    $null = Wait-Job -Job $jobsR -Timeout 5
    $stillR = @($jobsR | Where-Object { $_.State -eq "Running" })
    if ($stillR.Count -gt 0) {
      Stop-Burn -Jobs $jobsR
      $failR = (Get-Texto "a_r_travou")
    } else {
      $crashedR = @($jobsR | Where-Object { $_.State -eq "Failed" })
      if ($crashedR.Count -gt 0) { $failR = (Get-Texto "a_r_crash") }
    }
    Stop-Burn -Jobs $jobsR
  }
  if (-not [string]::IsNullOrEmpty($failR)) {
    return @{ Veredito = "FAIL"; Motivo = $failR; Stretch = $stretch; Clk = $tel.Clk; Marginal = $true }
  }
  if (($null -eq $tel2) -or ($null -eq $tel3)) {
    return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_r_sensores"); Stretch = $stretch; Clk = $tel.Clk; Marginal = $true }
  }
  if (($tel2.Tctl -gt 90) -or ($tel3.Tctl -gt 90)) {
    return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_r_tctl"); Stretch = $stretch; Clk = $tel.Clk; Marginal = $true }
  }
  $novosR = $null
  Show-SpinnerLinha -Texto (Get-Texto "a_whea_r") -Indice 1
  $novosR = Get-WheaDesde -Desde $tR
  Write-Tela ""
  if ($novosR.Count -gt 0) {
    $novosR | ForEach-Object { Write-Log (Get-Texto "a_whea_linha" $_.TimeCreated $_.Id) }
    return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_r_whea" $novosR.Count); Stretch = $stretch; Clk = $tel.Clk; Marginal = $true }
  }
  $s1 = $stretch
  $s2 = $tel2.Eff / $tel2.Clk
  $s3 = $tel3.Eff / $tel3.Clk
  $ord = @($s1, $s2, $s3) | Sort-Object
  $med = $ord[1]
  Write-Log (Get-Texto "a_r_mediana" ([math]::Round($med * 100,1)) ([math]::Round($s1 * 100,1)) ([math]::Round($s2 * 100,1)) ([math]::Round($s3 * 100,1)))
  if ($med -ge 0.95) {
    return @{ Veredito = "PASS"; Motivo = ""; Stretch = $med; Clk = $tel.Clk; Marginal = $true }
  }
  return @{ Veredito = "FAIL"; Motivo = (Get-Texto "a_r_mediana_fail" ([math]::Round($med * 100,1))); Stretch = $med; Clk = $tel.Clk; Marginal = $true }
}

Write-Log (Get-Texto "a_painel_titulo")
try {
  $cpuNome = (Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1).Name
  Write-Log (Get-Texto "a_cpu" $cpuNome)
} catch {
  Write-Log (Get-Texto "a_cpu_nao")
}
try {
  $offAtivos = (& $smu --get-offsets-terse 2>&1 | Out-String).Trim()
  Write-Log (Get-Texto "a_off" $offAtivos)
} catch {
  Write-Log (Get-Texto "a_off_fail")
}
try {
  $scalar = (& $smu --get-pbo-scalar 2>&1 | Out-String).Trim()
  Write-Log (Get-Texto "a_scalar" $scalar)
} catch {
  Write-Log (Get-Texto "a_scalar_fail")
}
Write-Log (Get-Texto "a_plano" $Inicio $Maximo $Passo $N $Segundos $Refino)
Write-Log (Get-Texto "g_aviso_temp")
Write-Log (Get-Texto "a_seq" $Inicio ($Inicio + $Passo) $Maximo $Refino)
$conf = Read-Host (Get-Texto "a_confirma")
if (-not (($conf -eq "S") -or ($conf -eq "s") -or ($conf -eq "Y") -or ($conf -eq "y"))) {
  Write-Log (Get-Texto "g_cancel_nada")
  exit 0
}

$script:melhorStretch = 0
$script:degrauIndice = 0
$script:degrauTotal = 0
if ($Passo -gt 0 -and $Maximo -ge $Inicio) { $script:degrauTotal = [math]::Floor(($Maximo - $Inicio) / $Passo) + 1 }
$melhor = 0
$motivoParada = ""
$marginais = @()
$passes = 0
$primeiroClk = $null
$ultimoClk = $null
$failMag = $null
$failMotivoGrosso = ""
$mag = $Inicio
while ($mag -le $Maximo) {
  $r = Test-DegrauMag -Mag $mag
  if ($r.Marginal) { $marginais += $mag }
  if ($r.Veredito -eq "PASS") {
    Write-Log (Get-Texto "a_degrau_pass" $mag)
    $melhor = $mag
    $script:melhorStretch = $r.Stretch
    $passes++
    if ($null -eq $primeiroClk) { $primeiroClk = $r.Clk }
    $ultimoClk = $r.Clk
    $mag += $Passo
  } else {
    Write-Log (Get-Texto "a_degrau_fail" $mag $r.Motivo)
    $failMag = $mag
    $failMotivoGrosso = $r.Motivo
    $motivoParada = (Get-Texto "a_falha_em" $mag $r.Motivo)
    break
  }
}

if ($null -ne $failMag) {
  # Refino unico: testa (ultimoPASS + Refino); se nenhum passou, testa Refino.
  # Monotonicidade assumida: nada mais fundo que o FAIL e tentado depois disso.
  $refMag = $melhor + $Refino
  if (($refMag -gt $melhor) -and ($refMag -lt $failMag)) {
    Write-Log (Get-Texto "a_refino_testando" $refMag $melhor $Refino)
    $rr = Test-DegrauMag -Mag $refMag -EhRefino
    if ($rr.Marginal -and ($marginais -notcontains $refMag)) { $marginais += $refMag }
    if ($rr.Veredito -eq "PASS") {
      Write-Log (Get-Texto "a_refino_pass" $refMag)
      $melhor = $refMag
      $script:melhorStretch = $rr.Stretch
      $passes++
      if ($null -eq $primeiroClk) { $primeiroClk = $rr.Clk }
      $ultimoClk = $rr.Clk
      $motivoParada = "$motivoParada" + (Get-Texto "a_suf_refpass" $refMag)
    } else {
      Write-Log (Get-Texto "a_refino_fail" $refMag $rr.Motivo)
      $motivoParada = "$motivoParada" + (Get-Texto "a_suf_reffail" $refMag $rr.Motivo)
    }
  } else {
    Write-Log (Get-Texto "a_refino_skip" $melhor $failMag)
  }
}

Write-Log ""
if ([string]::IsNullOrEmpty($motivoParada)) { $motivoParada = (Get-Texto "a_parada_teto" $Maximo) }
Write-Log (Get-Texto "a_parada" $motivoParada)
if ($melhor -gt 0) {
  Write-Log (Get-Texto "a_melhor" $melhor)
} else {
  Write-Log (Get-Texto "a_melhor_nenhum" $motivoParada)
}
$ganho = 0
if (($passes -ge 2) -and ($null -ne $primeiroClk) -and ($null -ne $ultimoClk)) {
  $ganho = [math]::Round($ultimoClk - $primeiroClk, 0)
}
Write-Log (Get-Texto "a_ganho" $ganho)
if ($marginais.Count -gt 0) {
  $listaMarg = (($marginais | Sort-Object -Unique | ForEach-Object { "-$_" }) -join ", ")
  Write-Log (Get-Texto "a_marginais" $listaMarg)
} else {
  Write-Log (Get-Texto "a_marginais_nenhum")
}
Write-Log (Get-Texto "a_bios")
Write-Log (Get-Texto "a_valide")
Write-Log (Get-Texto "a_log_em" $script:logFile)
