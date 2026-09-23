# Teste A/B de offsets: mesma carga sintetica, telemetria durante a carga, checagem WHEA
# Uso:
#   .\teste-ab.ps1 -OffsetB "-25,-25,-25,-25,-25,-25" -Segundos 180 -Threads 12 -TimeoutSeg 240
#   -OffsetA vazio = baseline (NAO toca nos offsets na fase A)
#   No fim, deixa o OffsetB aplicado (volatil - reboot restaura BIOS)
param(
  [string]$OffsetA = "",
  [string]$OffsetB = "-25,-25,-25,-25,-25,-25",
  [int]$Segundos = 180,
  [int]$Threads = 12,
  [int]$TimeoutSeg = ($Segundos + 60),
  [string]$ModoCarga = "All",
  [string]$GrupoCores = ""
)
$ErrorActionPreference = "Continue"
if ($TimeoutSeg -le 0) { $TimeoutSeg = $Segundos + 60 }
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "lib\Idioma.ps1")
$smu = Join-Path $root "tools\ryzen-smu-cli\ryzen-smu-cli.exe"
$dll = Join-Path $root "tools\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"
$logDir = Join-Path $root "logs"
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$script:logFile = Join-Path $logDir ("teste-ab-" + $ts + ".log")

function Write-Log {
  param([string]$Message)
  Write-Host $Message
  try { Add-Content -LiteralPath $script:logFile -Value $Message -Encoding UTF8 } catch {}
}

$launcherNruns = 2
$grupoCoresNorm = ""
if ($null -ne $GrupoCores) { $grupoCoresNorm = $GrupoCores.Trim() }
if (-not [string]::IsNullOrWhiteSpace($grupoCoresNorm)) {
  if ($grupoCoresNorm -ieq "all-grupos") {
    $modoNormTmp = "All"
    if (-not [string]::IsNullOrWhiteSpace($ModoCarga)) { $modoNormTmp = $ModoCarga.Trim() }
    $nfisTmp = 6
    try {
      $cpuTmp = @(Get-WmiObject Win32_Processor -ErrorAction Stop)[0]
      if (($null -ne $cpuTmp) -and ($cpuTmp.NumberOfCores -gt 0)) { $nfisTmp = [int]$cpuTmp.NumberOfCores }
    } catch {}
    if ($nfisTmp -le 0) { $nfisTmp = 6 }
    if ($modoNormTmp -ieq "Single") { $launcherNruns = $nfisTmp }
    elseif ($modoNormTmp -ieq "Dual") { $launcherNruns = [int][math]::Ceiling($nfisTmp / 2.0) }
    elseif ($modoNormTmp -ieq "Half") { $launcherNruns = 2 }
    else { $launcherNruns = 2 }
  } else {
    $launcherNruns = 1
  }
}
if ($launcherNruns -lt 1) { $launcherNruns = 1 }
$launcherTimeoutSeg = ($launcherNruns * ($Segundos + 45)) + 120
if ($launcherTimeoutSeg -lt 300) { $launcherTimeoutSeg = 300 }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  . (Join-Path $PSScriptRoot "lib\Elevacao.ps1")
  $argThreads = ""
  if ($PSBoundParameters.ContainsKey("Threads")) { $argThreads = " -Threads $Threads" }
  Invoke-Elevado -ScriptPath $PSCommandPath -Argumentos "-OffsetA `"$OffsetA`" -OffsetB `"$OffsetB`" -Segundos $Segundos$argThreads -TimeoutSeg $TimeoutSeg -ModoCarga `"$ModoCarga`" -GrupoCores `"$GrupoCores`"" -TimeoutSeg $launcherTimeoutSeg
  exit
}

if (-not (Test-Path -LiteralPath $dll)) {
  Write-Log "ERRO: LibreHardwareMonitorLib.dll nao encontrada em $dll. Rode scripts\1-baixar-ferramentas.ps1 primeiro."
  exit 1
}
Add-Type -Path $dll

function Get-ContagemCpu {
  $nf = 6
  $nl = 12
  try {
    $procs = Get-WmiObject Win32_Processor -ErrorAction Stop
    $p0 = @($procs)[0]
    if ($null -ne $p0) {
      if ($p0.NumberOfCores -gt 0) { $nf = [int]$p0.NumberOfCores }
      if ($p0.NumberOfLogicalProcessors -gt 0) { $nl = [int]$p0.NumberOfLogicalProcessors }
    }
  } catch {}
  if ($nf -le 0) { $nf = 6 }
  if ($nl -le 0) { $nl = $nf * 2 }
  return @{ Fisicos = $nf; Logicos = $nl }
}

function Get-MascaraAfinidade {
  param([int[]]$Cores, [int]$Nfis, [int]$Nlog)
  [Int64]$mask = 0
  $smt = ($Nlog -ge ($Nfis * 2))
  foreach ($c in $Cores) {
    if ($smt) {
      $l1 = $c * 2
      $l2 = $c * 2 + 1
      if (($l1 -ge 0) -and ($l1 -lt 62)) { $mask = $mask -bor ([Int64]1 -shl $l1) }
      if (($l2 -ge 0) -and ($l2 -lt 62)) { $mask = $mask -bor ([Int64]1 -shl $l2) }
    } else {
      if (($c -ge 0) -and ($c -lt 62)) { $mask = $mask -bor ([Int64]1 -shl $c) }
    }
  }
  return $mask
}

function Set-AfinidadeJobs {
  param($Jobs, [Int64]$Mask)
  if ($Mask -eq 0) { return $true }
  try {
    $antes = @()
    try { $antes = @(Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id) } catch { $antes = @() }
    Start-Sleep -Seconds 1
    $meuPid = $PID
    $candidatos = @()
    try {
      $filhos = Get-WmiObject Win32_Process -Filter ("ParentProcessId=" + $meuPid) -ErrorAction Stop
      foreach ($f in @($filhos)) {
        if ($f.Name -match "powershell") { $candidatos += [int]$f.ProcessId }
      }
    } catch {}
    try {
      $depois = @(Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
      foreach ($id in @($depois)) {
        if ($antes -notcontains $id) {
          if ($candidatos -notcontains $id) { $candidatos += $id }
        }
      }
    } catch {}
    if ($candidatos.Count -eq 0) { return $false }
    $okAlgum = $false
    foreach ($pid in $candidatos) {
      try {
        $pr = Get-Process -Id $pid -ErrorAction Stop
        $pr.ProcessorAffinity = [System.IntPtr]::new($Mask)
        $okAlgum = $true
      } catch {}
    }
    return $okAlgum
  } catch { return $false }
}

function Read-Cpu {
  param($label)
  $c = New-Object LibreHardwareMonitor.Hardware.Computer
  $c.IsCpuEnabled = $true
  $c.Open() | Out-Null
  Start-Sleep -Seconds 2
  $out = @{ Eff = 0; Clk = 0; Stretch = 0; Tctl = 0 }
  foreach ($hw in $c.Hardware) {
    if ($hw.HardwareType -eq "Cpu") {
      $hw.Update() | Out-Null
      $temp = ($hw.Sensors | Where-Object { $_.SensorType -eq "Temperature" -and $_.Name -match "Tctl" }).Value
      $pwr  = ($hw.Sensors | Where-Object { $_.SensorType -eq "Power" -and $_.Name -eq "Package" }).Value
      $svi2 = ($hw.Sensors | Where-Object { $_.SensorType -eq "Voltage" -and $_.Name -eq "Core (SVI2 TFN)" }).Value
      $clk  = ($hw.Sensors | Where-Object { $_.SensorType -eq "Clock" -and $_.Name -eq "Cores (Average)" }).Value
      $eff  = ($hw.Sensors | Where-Object { $_.SensorType -eq "Clock" -and $_.Name -eq "Cores (Average Effective)" }).Value
      if ($null -eq $temp -or $null -eq $pwr -or $null -eq $svi2 -or $null -eq $clk -or $null -eq $eff) {
        Write-Log "ERRO: sensores indisponiveis (LibreHardwareMonitor nao retornou Tctl/PPT/SVI2/clocks). Rode como admin e confira o LibreHardwareMonitor."
        $c.Close() | Out-Null
        exit 1
      }
      Write-Log ("{0}: Tctl={1}C | PPT={2}W | SVI2={3}V | clkMed={4}MHz | effMed={5}MHz" -f `
        $label, [math]::Round($temp,1), [math]::Round($pwr,1), [math]::Round($svi2,3), `
        [math]::Round($clk,0), [math]::Round($eff,0))
      $out.Eff = [math]::Round($eff,0)
      $out.Clk = [math]::Round($clk,0)
      $out.Tctl = [math]::Round($temp,1)
      if ($clk -gt 0) { $out.Stretch = [math]::Round(($eff / $clk) * 100, 1) }
    }
  }
  $c.Close() | Out-Null
  return $out
}

function Burn {
  param([int]$seconds, [int]$ThreadCount, [Int64]$AffinityMask = 0, [string]$GrupoId = "")
  $sb = { param($s) $end = (Get-Date).AddSeconds($s); $x = 1.234567; while ((Get-Date) -lt $end) { for ($k = 0; $k -lt 3000; $k++) { $x = [math]::Sqrt($x * 1.000001 + $k * 0.0000001) + 0.0000001; $x = [math]::Sin($x) + [math]::Cos($x) + 2.0 } } }
  $list = @()
  for ($i = 1; $i -le $ThreadCount; $i++) { $list += Start-Job -ScriptBlock $sb -ArgumentList $seconds }
  if ($AffinityMask -ne 0) {
    $ok = Set-AfinidadeJobs -Jobs $list -Mask $AffinityMask
    if ($ok) {
      Write-Log ("Affinity 0x{0:X} aplicada no grupo {1}." -f $AffinityMask, $GrupoId)
    } else {
      Write-Log (Get-Texto "t_affinity_fallback")
    }
  }
  return $list
}

function Stop-Burn {
  param($Jobs)
  if ($null -eq $Jobs) { return }
  foreach ($j in $Jobs) { try { Stop-Job -Job $j -ErrorAction SilentlyContinue } catch {} }
  foreach ($j in $Jobs) { try { Remove-Job -Job $j -Force -ErrorAction SilentlyContinue } catch {} }
}

function Check-Whea {
  param($minutos)
  $w = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddMinutes(-$minutos)} -ErrorAction SilentlyContinue
  if ($w) { $w | ForEach-Object { Write-Log ("WHEA: {0} id={1}" -f $_.TimeCreated, $_.Id) } } else { Write-Log "nenhum WHEA" }
}

function Get-WheaCount {
  param($minutos)
  try {
    $w = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddMinutes(-$minutos)} -ErrorAction SilentlyContinue
    if ($null -eq $w) { return 0 }
    return @($w).Count
  } catch { return 0 }
}

function Get-NomeCpu {
  try {
    $p = @(Get-WmiObject Win32_Processor -ErrorAction Stop)[0]
    if (($null -ne $p) -and (-not [string]::IsNullOrWhiteSpace($p.Name))) { return $p.Name.Trim() }
  } catch {}
  return "Unknown CPU"
}

function Get-BaseOffsets {
  param([string]$Csv, [int]$N)
  $vals = @()
  if (-not [string]::IsNullOrWhiteSpace($Csv)) {
    foreach ($p in ($Csv -split ",")) {
      $num = 0
      if ([int]::TryParse($p.Trim(), [ref]$num)) { $vals += $num }
    }
  }
  $fallback = -25
  if ($vals.Count -gt 0) { $fallback = $vals[0] }
  $base = @()
  for ($i = 0; $i -lt $N; $i++) {
    if ($i -lt $vals.Count) { $base += $vals[$i] }
    elseif ($vals.Count -eq 1) { $base += $vals[0] }
    else { $base += $fallback }
  }
  return $base
}

function Get-VerditoGrupo {
  param([int]$Eff, [int]$Whea, [double]$Tctl = 0, [bool]$Parcial = $false)
  if ($Whea -eq -1) { return "FAIL" }
  if ($Eff -le 0) { return "FAIL" }
  if ($Tctl -gt 90) { return "FAIL" }
  if ($Whea -gt 0) { return "FAIL" }
  return "PASS"
}

function Get-SugestaoCsv {
  param($Grupos, $Ordenados, [int[]]$Base, [int]$N)
  $sug = @() + $Base
  $mapa = @{}
  foreach ($g in $Grupos) { $mapa[$g.Id] = $g.Cores }
  foreach ($r in $Ordenados) {
    $cores = $mapa[$r.Id]
    if ($null -eq $cores) { continue }
    $pass = ($r.Status -eq "PASS")
    foreach ($c in $cores) {
      if (($c -lt 0) -or ($c -ge $N)) { continue }
      if ($pass) {
        $v = [int]$Base[$c]
        if ($v -lt -30) { $v = -30 }
        $sug[$c] = $v
      } else {
        $v = [int]$Base[$c] + 5
        if ($v -lt -30) { $v = -30 }
        if ($v -gt 0) { $v = 0 }
        $sug[$c] = $v
      }
    }
  }
  return ($sug -join ",")
}

$ModoCargaNorm = "All"
if (-not [string]::IsNullOrWhiteSpace($ModoCarga)) { $ModoCargaNorm = $ModoCarga.Trim() }
$modoOk = $false
foreach ($m in @("All","Single","Dual","Half")) {
  if ($ModoCargaNorm -ieq $m) { $modoOk = $true; $ModoCargaNorm = $m }
}
if (-not $modoOk) {
  Write-Log (Get-Texto "t_modo_invalido" $ModoCarga)
  exit 1
}
$contagemCpu = Get-ContagemCpu
$nfis = [int]$contagemCpu.Fisicos
$nlog = [int]$contagemCpu.Logicos
$threadsExplicito = $PSBoundParameters.ContainsKey("Threads")
$ThreadsEff = [int]$Threads
if (-not $threadsExplicito) {
  if ($ModoCargaNorm -ieq "Single") { $ThreadsEff = 2 }
  elseif ($ModoCargaNorm -ieq "Dual") { $ThreadsEff = 4 }
  elseif ($ModoCargaNorm -ieq "Half") { $ThreadsEff = $nfis }
  elseif ($ModoCargaNorm -ieq "All") { $ThreadsEff = $nlog }
}
if ($ThreadsEff -le 0) { $ThreadsEff = 1 }
$grupoRaw = ""
if ($null -ne $GrupoCores) { $grupoRaw = $GrupoCores.Trim() }
$grupos = @()
if (-not [string]::IsNullOrWhiteSpace($grupoRaw)) {
  if ($grupoRaw -ieq "all-grupos") {
    if ($ModoCargaNorm -ieq "Single") {
      for ($i = 0; $i -lt $nfis; $i++) { $grupos += @{ Id = "$i"; Cores = @($i) } }
    } elseif ($ModoCargaNorm -ieq "Dual") {
      for ($i = 0; $i -lt $nfis; $i += 2) {
        if (($i + 1) -lt $nfis) { $grupos += @{ Id = "$i-$($i + 1)"; Cores = @($i, ($i + 1)) } }
        else { $grupos += @{ Id = "$i"; Cores = @($i) } }
      }
    } elseif ($ModoCargaNorm -ieq "Half") {
      $meio = [math]::Floor($nfis / 2)
      if ($meio -lt 1) { $meio = 1 }
      $cA = @()
      for ($i = 0; $i -lt $meio; $i++) { $cA += $i }
      $cB = @()
      for ($i = $meio; $i -lt $nfis; $i++) { $cB += $i }
      $grupos += @{ Id = ("0-" + ($meio - 1)); Cores = $cA }
      $grupos += @{ Id = ($meio.ToString() + "-" + ($nfis - 1)); Cores = $cB }
    }
  } else {
    $partes = $grupoRaw -split "[,; ]+"
    $coresSel = @()
    $grupoInvalido = $false
    foreach ($p in $partes) {
      if ([string]::IsNullOrWhiteSpace($p)) { continue }
      $n = 0
      if (-not [int]::TryParse($p.Trim(), [ref]$n)) { $grupoInvalido = $true; break }
      if (($n -lt 0) -or ($n -ge $nfis)) { $grupoInvalido = $true; break }
      if ($coresSel -notcontains $n) { $coresSel += $n }
    }
    if ($grupoInvalido -or ($coresSel.Count -eq 0)) {
      Write-Log (Get-Texto "t_grupo_invalido" $grupoRaw ($nfis - 1))
      exit 1
    }
    $grupos += @{ Id = ($coresSel -join ","); Cores = $coresSel }
  }
}

$half = [math]::Floor($Segundos / 2)

Write-Log "=== TESTE A/B start $(Get-Date -Format 'HH:mm:ss') ==="
Write-Log "Params: Segundos=$Segundos Threads=$ThreadsEff TimeoutSeg=$TimeoutSeg ModoCarga=$ModoCargaNorm Grupo=$grupoRaw Nfis=$nfis Nlog=$nlog"
Write-Log (Get-Texto "t_carga_linha" $ModoCargaNorm $ThreadsEff "")
Write-Log "--- offset atual ---"
try { $o = (& $smu --get-offsets-terse 2>&1 | Out-String); Write-Log $o } catch { Write-Log ("ERRO ao ler offsets: {0}" -f $_.Exception.Message); exit 1 }

if ($grupos.Count -gt 0) {
  Write-Log "--- aplicando offset B (sweep): $OffsetB ---"
  try { $ob0 = (& $smu --offset $OffsetB 2>&1 | Out-String); Write-Log $ob0 } catch { Write-Log ("ERRO ao aplicar OffsetB: {0}" -f $_.Exception.Message); exit 1 }
  $resultados = @()
  foreach ($g in $grupos) {
    $mask = Get-MascaraAfinidade -Cores $g.Cores -Nfis $nfis -Nlog $nlog
    Write-Log "--- grupo $($g.Id): burn $Segundos s ($ThreadsEff threads, Affinity=0x$($mask.ToString('X'))) ---"
    Write-Log (Get-Texto "t_carga_linha" $ModoCargaNorm $ThreadsEff (", grupo " + $g.Id))
    $wheaAntes = Get-WheaCount 10080
    $jobs = Burn -seconds $Segundos -ThreadCount $ThreadsEff -AffinityMask $mask -GrupoId $g.Id
    Start-Sleep -Seconds ($half + 5)
    $med = Read-Cpu ("G" + $g.Id)
    $rest = $TimeoutSeg - ($half + 5)
    if ($rest -lt 5) { $rest = 5 }
    $null = Wait-Job -Job $jobs -Timeout $rest
    $still = @($jobs | Where-Object { $_.State -eq "Running" })
    if ($still.Count -gt 0) {
      Stop-Burn -Jobs $jobs
      Write-Log ("TIMEOUT grupo $($g.Id): limite {0}s estourado, jobs do teste encerrados." -f $TimeoutSeg)
      $resultados += @{ Id = $g.Id; Eff = 0; Stretch = 0; Tctl = 0; Whea = -1 }
      continue
    }
    Stop-Burn -Jobs $jobs
    $wheaDepois = Get-WheaCount 10080
    $wheaDelta = $wheaDepois - $wheaAntes
    if ($wheaDelta -lt 0) { $wheaDelta = 0 }
    $resultados += @{ Id = $g.Id; Eff = [int]$med.Eff; Stretch = $med.Stretch; Tctl = [double]$med.Tctl; Whea = [int]$wheaDelta }
  }
  $cargaParcial = ($ThreadsEff -lt $nlog)
  foreach ($r in $resultados) { $r.Status = Get-VerditoGrupo -Eff ([int]$r.Eff) -Whea ([int]$r.Whea) -Tctl ([double]$r.Tctl) -Parcial $cargaParcial }
  if ($cargaParcial) {
    $ordenados = @($resultados | Sort-Object -Property @{ Expression = { [int]$_.Whea }; Descending = $false }, @{ Expression = { [int]$_.Eff }; Descending = $true })
  } else {
    $ordenados = @($resultados | Sort-Object -Property @{ Expression = { [int]$_.Eff }; Descending = $true }, @{ Expression = { [int]$_.Whea }; Descending = $false }, @{ Expression = { [double]$_.Stretch }; Descending = $true })
  }
  $stretchParcialTxt = Get-Texto "t_stretch_parcial"
  Write-Log (Get-Texto "t_ranking_cab")
  foreach ($r in $ordenados) {
    $wheaTxt = "$($r.Whea)"
    if ([int]$r.Whea -eq -1) { $wheaTxt = "TIMEOUT" }
    if ($cargaParcial) {
      Write-Log (Get-Texto "t_ranking_linha_p" $r.Id $r.Eff $stretchParcialTxt $wheaTxt $r.Status)
    } else {
      Write-Log (Get-Texto "t_ranking_linha_v" $r.Id $r.Eff $r.Stretch $wheaTxt $r.Status)
    }
  }
  if ($grupos.Count -ge 2) {
    try {
      $cpuNome = Get-NomeCpu
      $dataFmt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
      $baseVals = @(Get-BaseOffsets -Csv $OffsetB -N $nfis)
      $sugCsv = Get-SugestaoCsv -Grupos $grupos -Ordenados $ordenados -Base $baseVals -N $nfis
      $rankFile = Join-Path $logDir ("ranking-" + $ts + ".md")
      $linhas = @()
      $linhas += (Get-Texto "t_rank_titulo" $dataFmt)
      $linhas += ""
      $linhas += (Get-Texto "t_rank_cpu" $cpuNome $nfis $nlog)
      $linhas += (Get-Texto "t_rank_params" $OffsetB $ModoCargaNorm)
      $linhas += ""
      $linhas += (Get-Texto "t_rank_tab_cab")
      $linhas += "|---|---|---|---|---|"
      foreach ($r in $ordenados) {
        $wheaTxt = "$($r.Whea)"
        if ([int]$r.Whea -eq -1) { $wheaTxt = "TIMEOUT" }
        $stretchCell = ("" + $r.Stretch + "%")
        if ($cargaParcial) { $stretchCell = $stretchParcialTxt }
        $linhas += ("| " + $r.Id + " | " + $r.Eff + " | " + $stretchCell + " | " + $wheaTxt + " | " + $r.Status + " |")
      }
      $linhas += ""
      $melhor = $ordenados | Where-Object { $_.Status -eq "PASS" } | Select-Object -First 1
      if ($null -ne $melhor) { $linhas += (Get-Texto "t_rank_rec_melhor" $melhor.Id $melhor.Eff) }
      foreach ($r in $ordenados) {
        if ($r.Status -ne "PASS") {
          $wheaTxt = "$($r.Whea)"
          if ([int]$r.Whea -eq -1) { $wheaTxt = "TIMEOUT" }
          $linhas += (Get-Texto "t_rank_rec_ruim" $r.Id $wheaTxt)
        }
      }
      $linhas += ""
      $linhas += (Get-Texto "t_rank_sug_csv" $sugCsv)
      $linhas += (Get-Texto "t_rank_sug_como")
      $textoRank = ($linhas -join "`r`n") + "`r`n"
      [System.IO.File]::WriteAllText($rankFile, $textoRank, (New-Object System.Text.UTF8Encoding $false))
      Write-Log (Get-Texto "t_ranking_arquivo" $rankFile)
    } catch {
      Write-Log (Get-Texto "t_ranking_erro" $_.Exception.Message)
    }
  }
  Write-Log "=== fim $(Get-Date -Format 'HH:mm:ss') ==="
  Write-Log (Get-Texto "g_triagem_l1")
  Write-Log (Get-Texto "g_triagem_l2")
  Write-Log "AVISO: Offset B ($OffsetB) esta aplicado agora (volatil - reboot restaura BIOS). Rode o CPU-Z bench para validar o score!"
  Write-Log ("Log salvo em: {0}" -f $script:logFile)
  exit 0
}

Write-Log "--- fase A: burn $Segundos s ($ThreadsEff threads) ---"
Write-Log (Get-Texto "t_carga_linha" $ModoCargaNorm $ThreadsEff "")
if (-not [string]::IsNullOrEmpty($OffsetA)) {
  try { $oa = (& $smu --offset $OffsetA 2>&1 | Out-String); Write-Log $oa } catch { Write-Log ("ERRO ao aplicar OffsetA: {0}" -f $_.Exception.Message); exit 1 }
} else {
  Write-Log "fase A: baseline, sem tocar nos offsets (OffsetA vazio)"
}
$jobs = Burn -seconds $Segundos -ThreadCount $ThreadsEff
Start-Sleep -Seconds ($half + 5)
$null = Read-Cpu "A"
$rest = $TimeoutSeg - ($half + 5)
if ($rest -lt 5) { $rest = 5 }
$null = Wait-Job -Job $jobs -Timeout $rest
$still = @($jobs | Where-Object { $_.State -eq "Running" })
if ($still.Count -gt 0) {
  Stop-Burn -Jobs $jobs
  Write-Log ("TIMEOUT fase A: limite {0}s estourado, jobs do teste encerrados." -f $TimeoutSeg)
  Write-Log "RESULTADO: FALHA (timeout) exit=2"
  exit 2
}
Stop-Burn -Jobs $jobs

Write-Log "--- aplicando fase B: $OffsetB ---"
try { $ob = (& $smu --offset $OffsetB 2>&1 | Out-String); Write-Log $ob } catch { Write-Log ("ERRO ao aplicar OffsetB: {0}" -f $_.Exception.Message); exit 1 }
try { $oc = (& $smu --get-offsets-terse 2>&1 | Out-String); Write-Log $oc } catch { Write-Log ("ERRO ao ler offsets: {0}" -f $_.Exception.Message); exit 1 }

Write-Log "--- fase B: burn $Segundos s ($ThreadsEff threads) ---"
Write-Log (Get-Texto "t_carga_linha" $ModoCargaNorm $ThreadsEff "")
$jobs = Burn -seconds $Segundos -ThreadCount $ThreadsEff
Start-Sleep -Seconds ($half + 5)
$null = Read-Cpu "B"
$rest = $TimeoutSeg - ($half + 5)
if ($rest -lt 5) { $rest = 5 }
$null = Wait-Job -Job $jobs -Timeout $rest
$still = @($jobs | Where-Object { $_.State -eq "Running" })
if ($still.Count -gt 0) {
  Stop-Burn -Jobs $jobs
  Write-Log ("TIMEOUT fase B: limite {0}s estourado, jobs do teste encerrados." -f $TimeoutSeg)
  Write-Log "RESULTADO: FALHA (timeout) exit=2"
  exit 2
}
Stop-Burn -Jobs $jobs

Write-Log "--- WHEA ultima 30 min ---"
Check-Whea 30
Write-Log "=== fim $(Get-Date -Format 'HH:mm:ss') ==="
Write-Log (Get-Texto "g_triagem_l1")
Write-Log (Get-Texto "g_triagem_l2")
Write-Log "AVISO: Offset B ($OffsetB) esta aplicado agora (volatil - reboot restaura BIOS). Rode o CPU-Z bench para validar o score!"
Write-Log ("Log salvo em: {0}" -f $script:logFile)
