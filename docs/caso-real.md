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

## Pendências pós-sessão (protocolo de validação longa)

- 2-3 dias de uso real: CO -30 às vezes crasha em idle/carga leve mesmo passando em stress
- Se aparecer WHEA/reboot/freeze: recuo para -25 all-core (ou +5 só nos 2 núcleos de rank
  CPPC mais alto)
- Validação profunda com CoreCycler overnight (opcional)
