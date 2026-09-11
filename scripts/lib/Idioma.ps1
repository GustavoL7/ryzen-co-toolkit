# Idioma EN-default + PT (RF-11 / C-09) — PS 5.1 apenas.
# Uso: . (Join-Path $ScriptDir "lib\Idioma.ps1")
#   Get-Texto "<chave>" [<arg1> ...]  # aplica -f quando ha args extras
#   Get-Idioma                         # "en" (default) ou "pt"
#   Set-Idioma -Codigo "pt"            # persiste em scripts/lang.txt (gitignored)
# lang.txt ausente/invalido = en. Mesmos nomes de chave em en e pt.
$script:IdiomaLibDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($script:IdiomaLibDir)) { $script:IdiomaLibDir = Split-Path -Parent $PSCommandPath }
$script:IdiomaLangFile = Join-Path (Split-Path -Parent $script:IdiomaLibDir) "lang.txt"

$script:Strings = @{
  en = @{
    m_titulo = "=== Ryzen CO Toolkit - Menu ==="
    m_op1 = "1 - Install (download tools + register elevated task)"
    m_op2 = "2 - Show current state (offsets + temperature/power)"
    m_op3 = "3 - Apply per-core voltage tweak"
    m_op4 = "4 - Test before/after comparison (A/B test)"
    m_op5 = "5 - Check hardware errors (WHEA)"
    m_op6 = "6 - Automatic tune (recommended for beginners)"
    m_op7 = "7 - Tune per core (if option 6 failed at some step)"
    m_op8 = "8 - Language/Idioma (EN/PT)"
    m_op0 = "0 - Exit"
    m_prompt = "Choose [0-8]"
    m_invalida = "Invalid option. Type a number from 0 to 8."
    m_admin1 = "WARNING: you are NOT running as administrator."
    m_admin2 = "Some options will ask for permission (UAC) when used. That is normal."
    m_tools1 = "WARNING: tools\ folder not found."
    m_tools2 = "Run option 1 first (downloads and installs everything)."
    m_baixando = "Downloading tools from the official sources..."
    m_opt3_l1 = "Per-core voltage tweak: negative values use less"
    m_opt3_l2 = "voltage (e.g.: -25,-25,-25,-25,-25,-25 for 6 cores)."
    m_opt3_prompt = "Type the values separated by commas"
    m_opt3_vazio = "Cancelled: no value typed."
    m_opt4_l1 = "The test compares the PC before and after the tweak, under heavy load."
    m_opt4_prompt_off = "Type the tweak to test (Enter = -25,-25,-25,-25,-25,-25)"
    m_opt4_prompt_seg = "Duration of each phase in seconds (Enter = 120)"
    m_opt4_plano = "Will test the tweak {0} for {1} seconds per phase."
    m_opt4_aviso = "NOTE: at the end the tested tweak stays applied (temporary - lost on reboot)."
    m_cancel_teste = "Cancelled: no test was run."
    m_opt7_l1 = "Validates each core separately with CoreCycler + Prime95."
    m_opt7_modo = "Mode: Quick (Q) or Full (F)? (Enter = Quick)"
    m_opt7_nucleos = "Cores (e.g.: 0,1,2 or Enter = all)"
    m_ate_logo = "See you!"
    m_lang_pt = "Language: Portuguese (PT). Applies from the next redraw."
    m_lang_en = "Language: English (EN). Applies from the next redraw."
    g_aviso_temp = "NOTE: the tweak is temporary - lost on reboot or sleep."
    g_confirma = "Confirm? (Y/N)"
    g_cancel_nada = "Cancelled: nothing was applied."
    a_painel_titulo = "=== Automatic all-core tune ==="
    a_painel_refino_cab = "--- refine -{0} all-core ({1}) ---"
    a_painel_degrau_cab = "--- step -{0} all-core ({1}) --- [{2}/{3}]"
    a_painel_refino_linha = "Refine | offset -{0} all-core"
    a_painel_degrau_linha = "Step {0}/{1} | offset -{2} all-core"
    a_painel_offset = "Offset: {0}"
    a_painel_melhor = "Best so far: stretch {0}%"
    a_painel_melhor_nenhum = "Best so far: none yet"
    a_medindo = "measuring sensors..."
    a_medindo_r1 = "measuring sensors (re-test 1/2)..."
    a_medindo_r2 = "measuring sensors (re-test 2/2)..."
    a_whea = "checking WHEA..."
    a_whea_r = "checking WHEA (re-test)..."
    a_log_degrau = "--- step -{0} all-core ({1}) ---"
    a_erro_aplicar = "error applying offsets: {0}"
    a_burn_falha = "load did not start: {0}"
    a_carga_travou = "load hung/timed out (crash or unstable)"
    a_carga_crash = "load failed (crash)"
    a_sensores = "sensors unavailable (no Tctl/clock reading)"
    a_medido = "Measured: Tctl={0}C | PPT={1}W | clkAvg={2}MHz | effAvg={3}MHz | stretch={4}%"
    a_tctl = "Tctl {0}C above 90C"
    a_stretch_severo = "severe clock-stretching: effective {0}MHz = {1}% of {2}MHz (floor 80%)"
    a_stretch_degrada = "stretch dropped: {0}% vs sweep best {1}% (8pp+ drop)"
    a_whea_linha = "WHEA: {0} id={1}"
    a_whea_novos = "{0} new WHEA(s) during the step"
    a_marginal = "Step -{0}: MARGINAL (stretch {1}%) - re-testing..."
    a_r_burn = "re-test: load did not start: {0}"
    a_r_travou = "re-test: load hung/timed out (crash or unstable)"
    a_r_crash = "re-test: load failed (crash)"
    a_r_sensores = "re-test: sensors unavailable"
    a_r_tctl = "re-test: Tctl above 90C"
    a_r_whea = "re-test: {0} new WHEA(s)"
    a_r_mediana = "RE-TEST: median {0}% (samples {1}%, {2}%, {3}%)"
    a_r_mediana_fail = "re-test: median {0}% below 95%"
    a_cpu = "CPU: {0}"
    a_cpu_nao = "CPU: (not identified)"
    a_off = "Active offsets: {0}"
    a_off_fail = "Active offsets: (read failed)"
    a_scalar = "Scalar: {0}"
    a_scalar_fail = "Scalar: (--get-pbo-scalar flag not supported or read failed)"
    a_dll_erro = "ERROR: LibreHardwareMonitorLib.dll not found at {0}. Run scripts\1-baixar-ferramentas.ps1 first."
    a_plano = "Plan: coarse sweep -{0} to -{1}, step {2}, {3} cores, {4}s load per step + single +{5} refine after FAIL."
    a_seq = "The test will apply -{0}, -{1} ... up to -{2} or until it fails; if a step fails, it tests one refine (last PASS + {3}) and stops."
    a_confirma = "Confirm the automatic tune? (Y/N)"
    a_degrau_pass = "Step -{0} all-core: PASS"
    a_degrau_fail = "Step -{0} all-core: FAIL ({1})"
    a_falha_em = "FAIL at -{0} ({1})"
    a_refino_testando = "Refine: testing -{0} (last PASS -{1} + {2})..."
    a_refino_pass = "Refine -{0} all-core: PASS"
    a_refino_fail = "Refine -{0} all-core: FAIL ({1})"
    a_suf_refpass = "; refine -{0} PASS"
    a_suf_reffail = "; refine -{0} FAIL ({1})"
    a_refino_skip = "Refine: no valid step between -{0} and -{1} (skipping refine)."
    a_parada = "Stop: {0}"
    a_parada_teto = "ceiling -{0} reached, all steps PASS"
    a_melhor = "BEST: -{0} all-core"
    a_melhor_nenhum = "BEST: -0 all-core (no step passed; reason: {0})"
    a_ganho = "GAIN: +{0} MHz (last PASS clkAvg minus first PASS clkAvg)"
    a_marginais = "MARGINAL: {0} (passed the re-test or failed the median - candidates for future per-core tweak)"
    a_marginais_nenhum = "MARGINAL: none"
    a_bios = "Save the winning value in the BIOS: Advanced > AMD Overclocking > PBO > Curve Optimizer."
    a_valide = "Validate 2-3 days of real use (idle too) before saving it for good."
    a_log_em = "Log saved to: {0}"
    v_cc_falta = "ERROR: CoreCycler not found in tools\. Run menu option 1 first (it downloads and extracts everything)."
    v_p95_falta = "ERROR: Prime95 not extracted under test_programs\p95\. Run menu option 1 first (it downloads Prime95)."
    v_cfg_falta = "ERROR: CoreCycler config.ini not found. Run menu option 1 first."
    v_modo_rapido = "Quick mode: Prime95 SSE Small, ~4-6 min per core (1 pass; good for screening)."
    v_modo_completo = "Full mode: Prime95 SSE All, ~40-65 min per core (takes hours; final validation)."
    v_modo_prompt = "Choose the mode [Quick/Full] (Enter = Quick)"
    v_nome_rapido = "Quick"
    v_nome_completo = "Full"
    v_nucleo_erro = "ERROR: no valid core in -Nucleos (use csv like 0,1,2 or all)."
    v_est_rapido = "~{0} min total ({1} core(s) x ~4-6 min)"
    v_est_completo = "~{0} to ~{1} min total ({2} core(s) x ~40-65 min; leave it running)"
    v_confirma_linha = "Will validate {0} core(s) [{1}] in {2} mode (Prime95 SSE {3})."
    v_duracao = "Estimated time: {0}."
    v_cancelado = "Cancelled: nothing was run."
    v_config = "[config] CoreCycler set: PRIME95/SSE {0}, runtime {1} (backup in .bak-validar-nucleos)."
    v_iniciando = "[starting] CoreCycler... (close its window with CTRL+C if you need to stop)"
    v_timeout = "Time limit reached. Stopping CoreCycler and analyzing the partial log..."
    v_aguardando = "[waiting] CoreCycler running... (limit in ~{0} min)"
    v_fim = "[done] CoreCycler exited (exit={0}). Analyzing the log..."
    v_rel_cab = "=== validate-cores {0} mode={1} FFT={2} runtime={3} cores={4} ==="
    v_rel_log = "CoreCycler log: {0}"
    v_rel_aviso = "WARNING: no Set to Core found in the log; listing targets with no test verdict."
    v_nucleo_fail = "CORE {0}: FAIL"
    v_nucleo_pass = "CORE {0}: PASS"
    v_sugestao = "Suggestion: back off 5 points on core(s) {0} via menu option 3."
    v_sem_falha = "No failures: current offsets passed the {0} validation."
    v_resumo = "[summary] {0}"
    v_restaurado = "[restored] original config.ini put back."
  }
  pt = @{
    m_titulo = "=== Ryzen CO Toolkit - Menu ==="
    m_op1 = "1 - Instalar (baixar ferramentas + registrar tarefa elevada)"
    m_op2 = "2 - Ver estado atual (offsets + temperatura/consumo)"
    m_op3 = "3 - Aplicar ajuste de voltagem por nucleo"
    m_op4 = "4 - Testar comparando antes/depois (teste A/B)"
    m_op5 = "5 - Checar erros de hardware (WHEA)"
    m_op6 = "6 - Ajuste automatico (recomendado para iniciantes)"
    m_op7 = "7 - Afinar por nucleo (se a opcao 6 falhou em algum degrau)"
    m_op8 = "8 - Language/Idioma (EN/PT)"
    m_op0 = "0 - Sair"
    m_prompt = "Escolha [0-8]"
    m_invalida = "Opcao invalida. Digite um numero de 0 a 8."
    m_admin1 = "AVISO: voce NAO esta como administrador."
    m_admin2 = "Algumas opcoes vao pedir permissao (UAC) na hora. Isso e normal."
    m_tools1 = "AVISO: pasta tools\ nao encontrada."
    m_tools2 = "Rode a opcao 1 primeiro (baixa e instala tudo)."
    m_baixando = "Baixando ferramentas das fontes oficiais..."
    m_opt3_l1 = "Ajuste de voltagem por nucleo: valores negativos usam menos"
    m_opt3_l2 = "voltagem (ex.: -25,-25,-25,-25,-25,-25 para 6 nucleos)."
    m_opt3_prompt = "Digite os valores separados por virgula"
    m_opt3_vazio = "Cancelado: nenhum valor digitado."
    m_opt4_l1 = "O teste compara o PC antes e depois do ajuste, com carga pesada."
    m_opt4_prompt_off = "Digite o ajuste a testar (Enter = -25,-25,-25,-25,-25,-25)"
    m_opt4_prompt_seg = "Duracao de cada fase em segundos (Enter = 120)"
    m_opt4_plano = "Vai testar o ajuste {0} por {1} segundos por fase."
    m_opt4_aviso = "AVISO: no fim o ajuste testado fica aplicado (temporario - some ao reiniciar)."
    m_cancel_teste = "Cancelado: nenhum teste foi rodado."
    m_opt7_l1 = "Valida cada nucleo separado com CoreCycler + Prime95."
    m_opt7_modo = "Modo: Rapido (R) ou Completo (C)? (Enter = Rapido)"
    m_opt7_nucleos = "Nucleos (ex.: 0,1,2 ou Enter = todos)"
    m_ate_logo = "Ate logo!"
    m_lang_pt = "Idioma: portugues (PT). Vale a partir do proximo redesenho."
    m_lang_en = "Idioma: ingles (EN). Vale a partir do proximo redesenho."
    g_aviso_temp = "AVISO: o ajuste e temporario - some se reiniciar ou suspender."
    g_confirma = "Confirmar? (S/N)"
    g_cancel_nada = "Cancelado: nada foi aplicado."
    a_painel_titulo = "=== Ajuste automatico all-core ==="
    a_painel_refino_cab = "--- refino -{0} all-core ({1}) ---"
    a_painel_degrau_cab = "--- degrau -{0} all-core ({1}) --- [{2}/{3}]"
    a_painel_refino_linha = "Refino | offset -{0} all-core"
    a_painel_degrau_linha = "Degrau {0}/{1} | offset -{2} all-core"
    a_painel_offset = "Offset: {0}"
    a_painel_melhor = "MELHOR parcial: stretch {0}%"
    a_painel_melhor_nenhum = "MELHOR parcial: nenhum ainda"
    a_medindo = "medindo sensores..."
    a_medindo_r1 = "medindo sensores (re-teste 1/2)..."
    a_medindo_r2 = "medindo sensores (re-teste 2/2)..."
    a_whea = "checando WHEA..."
    a_whea_r = "checando WHEA (re-teste)..."
    a_log_degrau = "--- degrau -{0} all-core ({1}) ---"
    a_erro_aplicar = "erro ao aplicar offsets: {0}"
    a_burn_falha = "burn nao iniciou: {0}"
    a_carga_travou = "carga travou/estourou o tempo (crash ou instavel)"
    a_carga_crash = "carga falhou (crash)"
    a_sensores = "sensores indisponiveis (sem leitura Tctl/clocks)"
    a_medido = "Medido: Tctl={0}C | PPT={1}W | clkMed={2}MHz | effMed={3}MHz | stretch={4}%"
    a_tctl = "Tctl {0}C acima de 90C"
    a_stretch_severo = "clock-stretching severo: effective {0}MHz = {1}% de {2}MHz (piso 80%)"
    a_stretch_degrada = "stretch degradou: {0}% vs melhor {1}% do sweep (queda 8pp+)"
    a_whea_linha = "WHEA: {0} id={1}"
    a_whea_novos = "{0} WHEA novo(s) durante o degrau"
    a_marginal = "Degrau -{0}: MARGINAL (stretch {1}%) - re-testando..."
    a_r_burn = "re-teste: burn nao iniciou: {0}"
    a_r_travou = "re-teste: carga travou/estourou o tempo (crash ou instavel)"
    a_r_crash = "re-teste: carga falhou (crash)"
    a_r_sensores = "re-teste: sensores indisponiveis"
    a_r_tctl = "re-teste: Tctl acima de 90C"
    a_r_whea = "re-teste: {0} WHEA novo(s)"
    a_r_mediana = "RE-TESTE: mediana {0}% (amostras {1}%, {2}%, {3}%)"
    a_r_mediana_fail = "re-teste: mediana {0}% abaixo de 95%"
    a_cpu = "CPU: {0}"
    a_cpu_nao = "CPU: (nao identificado)"
    a_off = "Offsets ativos: {0}"
    a_off_fail = "Offsets ativos: (leitura falhou)"
    a_scalar = "Scalar: {0}"
    a_scalar_fail = "Scalar: (flag --get-pbo-scalar nao suportada ou leitura falhou)"
    a_dll_erro = "ERRO: LibreHardwareMonitorLib.dll nao encontrada em {0}. Rode scripts\1-baixar-ferramentas.ps1 primeiro."
    a_plano = "Plano: passada grossa -{0} ate -{1}, passo {2}, {3} nucleos, carga {4}s por degrau + refino unico de +{5} apos FAIL."
    a_seq = "O teste vai aplicar -{0}, -{1} ... ate -{2} ou ate falhar; se um degrau falhar, testa um refino (ultimo PASS + {3}) e encerra."
    a_confirma = "Confirmar o ajuste automatico? (S/N)"
    a_degrau_pass = "Degrau -{0} all-core: PASS"
    a_degrau_fail = "Degrau -{0} all-core: FAIL ({1})"
    a_falha_em = "FAIL em -{0} ({1})"
    a_refino_testando = "Refino: testando -{0} (ultimo PASS -{1} + {2})..."
    a_refino_pass = "Refino -{0} all-core: PASS"
    a_refino_fail = "Refino -{0} all-core: FAIL ({1})"
    a_suf_refpass = "; refino -{0} PASS"
    a_suf_reffail = "; refino -{0} FAIL ({1})"
    a_refino_skip = "Refino: sem degrau valido entre -{0} e -{1} (pulando refino)."
    a_parada = "Parada: {0}"
    a_parada_teto = "teto -{0} atingido, todos os degraus PASS"
    a_melhor = "MELHOR: -{0} all-core"
    a_melhor_nenhum = "MELHOR: -0 all-core (nenhum degrau passou; motivo: {0})"
    a_ganho = "GANHO: +{0} MHz (clkMed ultimo PASS menos clkMed primeiro PASS)"
    a_marginais = "MARGINAIS: {0} (passaram no re-teste ou falharam na mediana - candidatos a ajuste futuro por nucleo)"
    a_marginais_nenhum = "MARGINAIS: nenhum"
    a_bios = "Grave o valor vencedor na BIOS: Advanced > AMD Overclocking > PBO > Curve Optimizer."
    a_valide = "Valide 2-3 dias de uso real (idle também) antes de gravar definitivo."
    a_log_em = "Log salvo em: {0}"
    v_cc_falta = "ERRO: CoreCycler nao encontrado em tools\. Rode a opcao 1 do menu primeiro (ela baixa e extrai tudo)."
    v_p95_falta = "ERRO: Prime95 nao extraido em test_programs\p95\. Rode a opcao 1 do menu primeiro (ela baixa o Prime95)."
    v_cfg_falta = "ERRO: config.ini do CoreCycler nao encontrado. Rode a opcao 1 do menu primeiro."
    v_modo_rapido = "Modo Rapido: Prime95 SSE Small, ~4-6 min por nucleo (1 passada; bom para triagem)."
    v_modo_completo = "Modo Completo: Prime95 SSE All, ~40-65 min por nucleo (leva horas; validacao final)."
    v_modo_prompt = "Escolha o modo [Rapido/Completo] (Enter = Rapido)"
    v_nome_rapido = "Rapido"
    v_nome_completo = "Completo"
    v_nucleo_erro = "ERRO: nenhum nucleo valido em -Nucleos (use csv como 0,1,2 ou all)."
    v_est_rapido = "~{0} min no total ({1} nucleo(s) x ~4-6 min)"
    v_est_completo = "~{0} min a ~{1} min no total ({2} nucleo(s) x ~40-65 min; deixe rodando)"
    v_confirma_linha = "Vai validar {0} nucleo(s) [{1}] no modo {2} (Prime95 SSE {3})."
    v_duracao = "Duracao estimada: {0}."
    v_cancelado = "Cancelado: nada foi executado."
    v_config = "[config] CoreCycler configurado: PRIME95/SSE {0}, runtime {1} (backup em .bak-validar-nucleos)."
    v_iniciando = "[iniciando] CoreCycler... (feche a janela dele com CTRL+C se precisar interromper)"
    v_timeout = "Tempo limite atingido. Encerrando o CoreCycler e analisando o log parcial..."
    v_aguardando = "[aguardando] CoreCycler rodando... (limite em ~{0} min)"
    v_fim = "[fim] CoreCycler encerrou (exit={0}). Analisando o log..."
    v_rel_cab = "=== validar-nucleos {0} modo={1} FFT={2} runtime={3} nucleos={4} ==="
    v_rel_log = "log CoreCycler: {0}"
    v_rel_aviso = "AVISO: nenhum Set to Core encontrado no log; listando os alvos sem veredito de teste."
    v_nucleo_fail = "NUCLEO {0}: FAIL"
    v_nucleo_pass = "NUCLEO {0}: PASS"
    v_sugestao = "Sugestao: recuar 5 pontos no(s) nucleo(s) {0} via opcao 3 do menu."
    v_sem_falha = "Nenhuma falha: offsets atuais passaram na validacao {0}."
    v_resumo = "[resumo] {0}"
    v_restaurado = "[restaurado] config.ini original devolvido."
  }
}

function Get-Idioma {
  $cod = "en"
  try {
    if (Test-Path -LiteralPath $script:IdiomaLangFile) {
      $raw = Get-Content -LiteralPath $script:IdiomaLangFile -Raw -ErrorAction SilentlyContinue
      if ($null -ne $raw) {
        $t = $raw.Trim().ToLowerInvariant()
        if (($t -eq "pt") -or ($t -eq "pt-br") -or ($t -eq "portugues")) { $cod = "pt" }
      }
    }
  } catch {}
  return $cod
}

function Set-Idioma {
  param([Parameter(Mandatory = $true)][string]$Codigo)
  $c = $Codigo.Trim().ToLowerInvariant()
  if ($c -ne "pt") { $c = "en" }
  try { Set-Content -LiteralPath $script:IdiomaLangFile -Value $c -Encoding UTF8 } catch {}
}

function Get-Texto {
  param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Chave,
    [Parameter(ValueFromRemainingArguments = $true)][object[]]$Formato
  )
  $lang = Get-Idioma
  $tab = $null
  if ($script:Strings.ContainsKey($lang)) { $tab = $script:Strings[$lang] }
  if ($null -eq $tab) { $tab = $script:Strings["en"] }
  $txt = $null
  if ($tab.ContainsKey($Chave)) { $txt = [string]$tab[$Chave] }
  if ([string]::IsNullOrEmpty($txt)) {
    $enTab = $script:Strings["en"]
    if ($enTab.ContainsKey($Chave)) { $txt = [string]$enTab[$Chave] } else { $txt = $Chave }
  }
  $planos = @()
  if ($null -ne $Formato) {
    foreach ($f in $Formato) {
      if (($f -is [System.Collections.IEnumerable]) -and (-not ($f -is [string]))) {
        foreach ($g in $f) { $planos += $g }
      } else {
        $planos += $f
      }
    }
  }
  if ($planos.Count -gt 0) {
    try { return ($txt -f $planos) } catch { return $txt }
  }
  return $txt
}
