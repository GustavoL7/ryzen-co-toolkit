# Caso real — Ryzen 5 5600 (Vermeer B2), sessão de 2026-09-09

Setup completo: **AMD Ryzen 5 5600** (6C/12T, 65 W, stepping B2), **Gigabyte B450M S2H**
(BIOS F67, 10/2025), 32 GB DDR4-3200 CL16 (16-20-20-39), RX 6600 XT, Windows 11 x64.
Objetivo do dono: **eficiência** (mais performance com mesmo consumo/temperatura e estabilidade),
não caça de recordes.

---

## Estado inicial

A BIOS já tinha PBO + Curve Optimizer **-15 all-core**. Medição CPU-Z: **629 ST / 4675 MT**,
~4.35 GHz all-core, SVI2 ~1.116 V, 64 °C — ou seja, PBO quase sem ganho sobre stock
(5600 stock faz ~4.4 GHz all-core; baseline stock de referência: **599 ST / 4674 MT**).

## Método

1. **Instrumentação** (a que virou o kit deste repo):
   - `ryzen-smu-cli` para aplicar/ler offsets CO direto no SMU (sobrepõe a BIOS até reboot)
   - `LibreHardwareMonitorLib` para telemetria por script (Tctl, PPT, SVI2 TFN, clocks, Effective Clocks)
   - Dispatcher via Task Scheduler com RunLevel Highest → **UAC confirmado 1 vez** para toda a sessão
2. **Teste A/B em degraus de 5** com carga sintética de 2 min por fase (PowerShell, 12 threads),
   telemetria lida no meio da carga + checagem de WHEA
3. Score CPU-Z antes/depois de cada passo significativo (valida contra clock-stretching)

## Resultados por degrau

| Config | Clock all-core (carga) | SVI2 | Tctl | PPT | CPU-Z ST | CPU-Z MT |
|---|---|---|---|---|---|---|
| Stock (referência) | — | — | — | — | 599 | 4674 |
| BIOS: CO -15 + Override +100 (início) | 4275 MHz | 1.087 V | 65.9 °C | 92.2 W | 629 | 4675 |
| CO -20 (CLI) + Override +100 | 4288 MHz | 1.075 V | 65.8 °C | 92.2 W | — | — |
| CO -25 (CLI) + Override +100 | 4342 MHz | 1.087 V | 65.9 °C | 92.2 W | — | — |
| CO -30 (CLI) + Override +100 | 4388 MHz | 1.075 V | 65.0 °C | 92.2 W | 631 | 4845 |
| **BIOS: CO -30 + Override +200** | 4450 MHz (amostra) | 1.104 V | 66.5 °C | 92.2 W | **641** | **4843** |

Validações CPU-Z públicas (multi-thread):
- Início: [valid.x86.fr/wqcyhs](https://valid.x86.fr/wqcyhs) — 629/4675
- CO -30 via CLI: [valid.x86.fr/5xcrk1](https://valid.x86.fr/5xcrk1) — 631/4845
- Final (BIOS -30 + Override +200): [valid.x86.fr/wswrpx](https://valid.x86.fr/wswrpx) — 641/4843

### Leituras importantes

- **PPT preso em 92.2 W em TODAS as fases** — o CPU estava limitado por potência. O CO negativo
  não baixou o consumo: **converteu o mesmo orçamento de potência em mais clock** (+113 MHz)
- Score MT subiu +3.6% com clock +1.7% — o -15 original tinha um pouco de baixa sustentação
  que o -30 corrigiu (Effective/Requested Clocks ~97% em todas as fases = sem stretching)
- Boost Override +200: empurrou o pico single para **4.65 GHz** (641 ST), sem tocar no all-core
  (limitado por PPT). Custo: mais tensão apenas nos bursts de 1 thread
- **Zero WHEA em todos os passos**

## Descoberta: suspend apaga os offsets do SMU

Ao suspender a máquina, os offsets aplicados via CLI foram descartados no wake (voltou ao -15 da
BIOS). Eventos do log: sleep 12:07:52 → resume 12:07:53, sem WHEA, sem reboot (uptime intacto).
O "PC reiniciou estranho" relatado era só a retomada normal de tela.

**Conclusão prática**: offsets via CLI são para EXPLORAR. A configuração definitiva vai para a
BIOS — que sobrevive a reboot E suspend.

## Config final (gravada na BIOS)

- Curve Optimizer: **-30 all-core** (teto do AGESA)
- Boost Override: **+200 MHz**
- PPT/TDC/EDC: como estavam (~92 W de PPT efetivo)
- Scalar: 1 (auto)

## Resultado líquido (vs stock)

| | Stock | Final (BIOS CO -30 + Override +200) | Delta vs stock |
|---|---|---|---|
| CPU-Z Single | 599 | 641 | **+7.0%** |
| CPU-Z Multi | 4674 | 4843 | **+3.6%** |
| Tctl em carga | — | 65-66.5 °C | — |
| Potência em carga | — | 92.2 W | — |

Do ponto de partida CO -15 (629/4675): +1.9% single, +3.6% multi.

+3.6% de multi e +7.0% de single **grátis** — mesmo consumo, mesma temperatura.

## Pendências pós-sessão (protocolo de validação longa) — CONCLUÍDO 2026-09-13

- ~~2-3 dias de uso real~~ ✅ 2 dias de uso real com **-30 all-core + Override +200,
  zero bugs/crashes/freezes** (inclui idle/uso leve — o modo de falha clássico do CO).
  Config declarada **estável final**; sem recuo necessário.
- CoreCycler overnight: segue opcional (núcleo a núcleo); virou a opção 7 do menu.

---

## Sessão de validação — auto-tune 2026-09-11 (opção 6 do menu)

Primeira corrida ponta a ponta do `scripts/auto-tune.ps1` (fases D–G do improve-all).
Condição diferente da sessão 09-09: **Boost Override +200 na BIOS** (09-09 usou +100
nos degraus CLI). Os offsets CLI sobrescrevem o SMU em absoluto, então cada degrau
testou o valor cheio indicado, independente da BIOS.

| Degrau | Tctl | PPT | clkMed | effMed | Stretch | Veredito |
|---|---|---|---|---|---|---|
| -5 | 67.9 °C | 92.2 W | 3954 MHz | 3959 MHz | 100.1% | PASS |
| -10 | 68.5 °C | 92.2 W | 3983 MHz | 3983 MHz | 100% | PASS |
| -15 | 68.6 °C | 92.2 W | 4050 MHz | 4045 MHz | 99.9% | PASS |
| -20 | 69.0 °C | 92.2 W | 4117 MHz | 4122 MHz | 100.1% | PASS |
| -25 | 69.0 °C | 92.2 W | 4179 MHz | 4176 MHz | 99.9% | PASS |
| -30 | 69.1 °C | 92.2 W | 4225 MHz | 4226 MHz | 100% | PASS |

**MELHOR: -30 all-core** (teto atingido, zero WHEA em todos os degraus).
Log bruto: `logs/` (gitignored) — `auto-tune-20260911-114338.log`.

### Leituras desta sessão

- **Clock sobe à medida que o CO aprofunda** (+267 MHz efetivos e +1,2 °C de -5 a -30, mesmo PPT):
  menos tensão → mais headroom dentro do mesmo orçamento de potência. O próprio
  sweep mostra o benefício, sem precisar de benchmark externo.
- **Stretch ~100% em todos os degraus** — depois do fix do burn em 12 threads;
  a corrida anterior (6 threads) media ~55% e reprovava chip saudável (falso-positivo).
- MHz **não comparáveis** com a sessão 09-09 (carga sintética diferente e override
  +200 vs +100) — o que valida aqui é stretch ~100% + zero WHEA, não o número absoluto.
- Confirma a config da BIOS (**-30 + Override +200**). Segue valendo o protocolo de
  validação longa acima: stress não pega crash em idle — 2-3 dias de uso real mandam.

---

## Sessão bench — limites PBO elevados na BIOS, 2026-09-19

Dono subiu PPT/TDC/EDC na BIOS (antes ~92 W efetivos). Captura `ler-sensores.ps1 -LoopSeconds 5`
durante bench CPU-Z (23 amostras, log bruto gitignored: `logs/bench-cpuz-20260919-1124.txt`):

| Fase | PPT | clkMed/effMed | Tctl | Stretch |
|---|---|---|---|---|
| Carga MT | **102.4 W cravados** | ~4500/~4490 MHz | 71.5 → 75.1 °C | 98-100% |
| Idle | 25-64 W | baixo (cores ociosos) | 47-62 °C | — |

CPU-Z: **640 ST / 4906 MT** (baseline 641/4843). ST inalterado (-0.2%, ruído — thread única
não é limitada por PPT); MT **+1.3%** (+63 pts) ao custo de +11% de potência e +6-10 °C.
**Zero WHEA** pós-bench. Troca válida se 75 °C em carga estiver OK; acima de ~80 °C deixa de valer.

Limites confirmados via Ryzen Master (leitura 2026-09-19): **PPT 100 W / TDC 70 A / EDC 100 A**
(≈ +10 sobre stock 88/60/90), BO +200, Scalar 1, CO -30 all-core nos 6 núcleos (Core 0-5).
Grade C0-C7 do SMUDebugTool mostrava "C4 = 0" — quirk de numeração da ferramenta (slots
fantasmas de CCD de 8); Ryzen Master confirma os 6 núcleos reais todos em -30. Pico 102.4 W
medido em carga ≈ teto de 100 W (variância de telemetria).

> **Telemetria × bench (2026-09-19, versão final):** sequência PPT 95 W: 4545 (captura LHM
> *iniciada no meio* do run — score ao vivo caiu ~100 pts na hora e seguiu descendo) → 4855
> (captura já rodando desde antes) → 4882 (sem captura). Mecanismo: o `Computer.Open()` +
> primeiro `Update()` do LHM é uma rajada cara (enumera hardware); em regime, o poll de 5 s
> custa pouco (~0.5%: 4855 vs 4882). Regras: (1) nunca INICIAR captura no meio do bench —
> comece antes (1 amostra de aquecimento) ou depois; (2) RM fechado (ST 584→641); (3) descartar
> 1º run pós-boot. Melhoria futura: `ler-sensores.ps1` abre/fecha o Computer a cada amostra —
> abrir uma vez e só dar Update reduziria a perturbação.

### Joelho do PPT (runs limpos, sem captura, 2026-09-19)

| PPT | CPU-Z MT | pts/W | Tctl carga |
|---|---|---|---|
| 92 W (BIOS orig.) | 4843 | 52.6 | ~66 °C |
| 95 W | 4882 | **51.4** | ~70 °C |
| 100 W | 4937 | 49.4 | ~75 °C |

Retorno aprox. linear (~11-13 pts/W) em 92-100 W — sem dobra brusca nessa faixa; 95 W é o
equilíbrio (‑1.1% score por ‑5% watts vs 100 W). Ponto 88 W opcional para achar a dobra real.

---

## Sessão gaming — sweep Single + mix por núcleo, 2026-09-23

Motivo: depois de 3 dias estáveis em **-30 all-core + Override +200**, um update do Tarkov
(rodando com Lossless Scaling) trouxe crash + BSOD `0x13A` (erro de anel do kernel, típico de
CO agressivo em boost alto de poucos núcleos). Fallback imediato para **-25 all-core + Override
+100**, estável — e ponto de partida do retune fino desta sessão.

PBO atual (owner-reported, **a confirmar via Ryzen Master**): **PPT 80 W / TDC 75 A / EDC 80 A
+ Override +100**. BIOS anterior documentada era +200 e 100/70/100 — não comparar MHz com as
sessões antigas; o que valida aqui é PASS + zero WHEA.

Ferramenta nova do kit (ciclos 8-10): `teste-ab.ps1 -ModoCarga Single|Dual|Half` (perfil gaming:
poucos núcleos, boost alto, PPT não chapado) + `-GrupoCores all-grupos` com affinity, gravando
`logs/ranking-<ts>.md` com tabela por grupo (effMed, stretch, WHEA, PASS/FAIL) + bloco `SUGESTAO:`
com CSV pronto de 6 valores para aplicar via opção 3.

Sweeps Single (1 thread por grupo, 6/6 grupos): **-25 → 6/6 PASS, zero WHEA; -30 → 6/6 PASS,
zero WHEA**. Carga parcial dilui o effMed (núcleos ociosos derrubam o "Average Effective"),
então o veredito em Single/Dual/Half ignora stretch — FAIL só por crash/TIMEOUT, Tctl > 90
ou WHEA > 0 (stretch reportado como `N/A (carga parcial)`).

Mix validado (SUGESTAO do ranking, sem forçar além do teto -30): **-29,-28,-30,-28,-30,-28**
(núcleos 2 e 4 em -30; 0 em -29; 1, 3 e 5 em -28).

Decisão: **perfil único** — o mix vai para a BIOS após 3 dias de uso real (inclui Tarkov com
e sem Lossless Scaling). Sem modo-jogo/modo-normal separados: um perfil que passa no gaming
e segura rajada de compilação vale para tudo.
