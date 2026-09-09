# Fontes da pesquisa (coletadas em 2026-09-09, com data de cada fonte)

> Todas as afirmações do [guia](guia-completo.md) vêm destas fontes + validação prática.
> Marcadores: [CONSENSO] aceito pela comunidade | [DISPUTADO] divergência entre fontes | [ESPECULAÇÃO] sem fonte sólida

## Tensão segura / degradação (Zen 3)

- FIT voltage como limite real do chip; método de medição (PBO stock + Prime95 → ler SVI2 TFN): [CONSENSO]
  - https://linustechtips.com/topic/1316226-maximum-safe-24-7-voltage-for-ryzen-5800x (2023-05-16)
  - https://forums.tomshardware.com/threads/pls-help-how-to-change-cpu-frequency-in-bios.3719143 (2021-08-18)
- FIT típico Zen 3 = 1.20–1.30 V; faixa 24/7 manual 1.30–1.325 V (1.35 V alto): [CONSENSO]
  - idem LinusTechTips acima + https://cycledao.xyz/amd-ryzen-overclocking-guide-unlocking-pbo-and-manual-tuning (2026-07-26)
- Zen 2 (3600) tinha o MESMO teto 1.325–1.35 V; Buildzoid degradou 3700X a 1.375 V: [CONSENSO]
  - https://www.overclock.net/threads/help-with-oc-ryzen-5-3600.1792195 (2021-06-24)
  - https://www.reddit.com/r/Amd/comments/fcdt4z/what_is_truly_the_safe_voltage_range_for_r5_3600 (2020-03-02)
- Tabela MSI/Hallock (5600X até 1.45 V) = validação de estabilidade de fábrica, NÃO daily: [DISPUTADO]
  - https://blog.progressiverobot.com/amd-its-board-partners-discuss-ryzen-5000-zen-3-cpu-undervolting-memory-overclocking-500-series-agesa-support (2020-11-07)
- **"1.2 V degrada o 5600" = [ESPECULAÇÃO sem fonte]** — provável confusão com Vcore médio em jogo (~1.1–1.2 V)
  - https://linustechtips.com/topic/1363946-are-these-5600x-stock-voltages-normal (2021-08-10)
- Stepping B2 (5600 tardio): sem mudança oficial de perf; anedotas de B2 mais frio/eficiente: [DISPUTADO]
  - https://www.tomshardware.com/news/amd-ryzen-5000-b2-stepping-cpus-dont-bring-any-benefits (2021-05-19)
  - https://www.overclock.net/threads/ryzen-5xxx-b2-revision-stepping-post-here-your-manufacturing-dates.1796602/ (2022-01/02)
- Degradação real = tensão + corrente + temperatura sustentadas; FIT protege em stock/PBO, não em OC manual:
  - https://www.overclock.net/threads/understanding-the-sizing-and-limits-of-ppt-tdc-and-edc.1732088 (2019-08-28, The Stilt)

## Leitura de tensão

- SVI2 TFN é a referência (direto do VRM interno); Vcore do sensor da placa é impreciso: [CONSENSO]
  - https://www.hwinfo.com/forum/threads/cpu-core-voltage-vs-vcore.5683 (2019-05-07)
  - https://www.hwinfo.com/forum/threads/vcore-vs-cpu-core-voltage-svi2-tfn.7728 (2021-11-26)
- Spikes de 1.4–1.5 V em idle são normais e seguros (AMD via moderadores): [CONSENSO]
  - https://forums.tomshardware.com/threads/r5-5600x-pushing-up-to-1-5v-idle-because-pbo-tells-it-to.3697259/ (2021-04-06)

## Plataforma AM4

- VSOC ≤1.20 V daily, >1.25 V risco: [CONSENSO]
  - https://www.overclock.net/threads/official-amd-ryzen-ddr4-24-7-memory-stability-thread.1628751/ (regra vigente 2026-08-26)
- SOC 1.05–1.15 V / VDDP 0.8–1.0 / VDDG IOD ≤1.05 / CCD ≤1.00 (guia RAM Zen 3): [CONSENSO]
  - https://www.overclock.net/threads/a-guide-to-ram-overclocking-on-zen-3.1798093/ (2025-10-09)
- PPT/TDC/EDC stock 65 W: PPT 88 W / TDC 60 A / EDC 90 A: [CONSENSO]
  - https://www.techpowerup.com/cpu-specs/ryzen-5-5600.c2743
  - https://linustechtips.com/topic/1428639-5600g-runs-hot/ (2022-05-02)

## Curve Optimizer (Zen 3)

- Mecânica do CO (curva V-F-T por core, step ~3-5 mV, range -30..+30): [CONSENSO]
  - https://skatterbencher.com/amd-curve-optimizer/ (2024-08-06)
  - https://www.reddit.com/r/Amd/comments/khtx1o/guide_zen_3_overclocking_using_curve_optimizer/ (2020-12-22)
  - https://www.pchardwarepro.com/en/Step-by-step-tutorial-on-pbo2-and-curve-optimizer-for-Ryzen-5000/ (2025-12-03)
- Particularidade Zen 3: 1 offset único (idle + load) → crash em idle é modo de falha documentado: [CONSENSO]
  - https://www.reddit.com/r/overclocking/comments/lg23db/ryzen_5900x_curve_optimizer_is_unstable_only_when/ (2021-02-09)
  - https://www.overclock.net/threads/system-unstable-on-idle.1795475/ (2021-12-09)
- Valores típicos 5600: all-core -10 a -25 comum; -30 minoria; per-core > all-core (melhores cores aguentam menos): [CONSENSO]
  - https://www.reddit.com/r/overclocking/comments/10048al/curve_optimizer_negative_limit/ (2022-12-31)
  - https://www.reddit.com/r/overclocking/comments/vn3o2m/critique_my_ryzen_5600_overclock/ (2022-06-29)
  - https://www.reddit.com/r/overclocking/comments/1shsuz5/r5_5600_with_pbo_curve_optimizer/ (2026-04-10)
- Clock-stretching silencioso (validar por SCORE, Effective < Requested): [CONSENSO]
  - https://www.reddit.com/r/overclocking/comments/xt6b9z/ryzen_5600_oc_curve_optimizer_help/ (2022-10-01)
- WHEA ID 18/19 como sintoma; APIC ID aponta o core culpado: [CONSENSO]
  - https://www.reddit.com/r/Amd/comments/krjnc4/advanced_guide_curve_optimizer_stability_test_and/ (2021-01-06)
- Boost Override +100 = sweet spot eficiência; +200 = +1.5% ST por +50% potência nos bursts: [CONSENSO]
  - https://www.pchardwarepro.com/en/Step-by-step-tutorial-on-pbo2-and-curve-optimizer-for-Ryzen-5000/ (2025-12-03)
- CO -15/-20 derruba 6–8 °C em load mantendo performance: [CONSENSO]
  - https://linustechtips.com/topic/1511955-ryzen-5-5600-pbo-settings/ (2023-06-09)

## Ferramentas

- PBO2 Tuner (PJVol/irusanov, ~2022, abandonado; WinRing0 sinalizado pelo Defender; NÃO persiste em reboot/sleep): [CONSENSO]
  - https://github.com/mrdobing/pbo2-tuner-auto-schedule
  - https://www.overclock.net/threads/pbo2-tuner-help-migrating-kernel-driver.1817765/ (2025-09)
  - https://github.com/PrimeO7/How-to-undervolt-AMD-RYZEN-5800X3D-Guide-with-PBO2-Tuner/blob/main/README.md
- ryzen-smu-cli (caminho CLI moderno p/ Zen 3, usado pelo CoreCycler v0.11+): [CONSENSO]
  - https://github.com/rawhide-kobayashi/ryzen-smu-cli
  - https://github.com/sp00n/CoreCycler/releases (v0.11.0.0 migrou WinRing0 → PawnIO)
- CoreCycler (workflow 1-core por vez, checa WHEA): [CONSENSO]
  - https://github.com/sp00n/CoreCycler
  - https://www.overclock.net/threads/corecycler-tool-for-testing-single-core-stability-e-g-curve-optimizer-settings.1777398/
- HWiNFO logging por CLI / LibreHardwareMonitor via PowerShell: [CONSENSO]
  - https://www.hwinfo.com/forum/threads/supported-command-line-parameters-in-hwinfo64-pro.8549/ (2026-05-13)
  - https://github.com/LibreHardwareMonitor/LibreHardwareMonitor
  - https://github.com/Lifailon/PowerShell.HardwareMonitor
- Ryzen Master: sem CLI; GUI oficial com Auto/Manual Offset: [CONSENSO]
  - https://www.amd.com/content/dam/amd/en/documents/products/software-tools/faq-curve-optimizer.pdf
  - https://docs.amd.com/r/en-US/68886-ryzen-master-user-guide/Curve-Optimizer
- OCCT CommandLine existe mas é só edição paga (Enterprise): [CONSENSO]
  - https://www.ocbase.com/occt/enterprise
- Ordem de teste (baseline → PBO → CO → limites → revalidar): [CONSENSO]
  - https://www.overclock.net/threads/amd-ryzen-curve-optimizer-per-core-curve-shaper-ddr5-oc.1814427/ (2026-08-24)
