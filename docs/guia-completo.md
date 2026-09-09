# Guia completo — Tuning de eficiência via Curve Optimizer (Zen 3)

> Fonte: pesquisa da comunidade (fontes datadas em [`fontes.md`](fontes.md)) + validação prática
> num Ryzen 5 5600 real (caso completo em [`caso-real.md`](caso-real.md)).

---

## 1. Teoria mínima

### O que o Curve Optimizer faz
O CO desloca a curva tensão-frequência-térmica que a AMD calibra de fábrica, por núcleo.
**Offset negativo = a mesma frequência com menos tensão.** Com o mesmo orçamento de potência
(PPT), sobra margem para o boost subir e se sustentar mais. Range permitido pelo AGESA:
**-30 a +30 por núcleo** (-30 é limite duro, não "estável garantido").

No Zen 3 (diferente do Zen 4), o CO é **um único offset por toda a curva** — afeta idle E load
juntos. Por isso o modo de falha clássico: **passa horas de stress, mas crasha em idle** (o pico
de burst single-thread em baixa carga fica sem tensão).

### O mito do "1.2 V degrada o 5600"
**Não existe limite de 1.2 V para Zen 3.** Nenhuma fonte defende esse número. O que existe:

- O limite real é o **FIT voltage individual**: a tensão que o próprio chip pede (SVI2 TFN) em
  carga pesada stock. Tipicamente **1.20–1.30 V**. Método de medição: PBO stock + Prime95 FFT
  pequeno → ler SVI2 TFN = seu FIT. No tuning manual, não passar disso.
- Faixa aceita pela comunidade para uso 24/7: **1.30–1.325 V** (o Zen 2 / R5 3600 tinha o MESMO
  teto de 1.325–1.35 V — o "limite do 3600" e do 5600 são praticamente iguais).
- **Spikes de Vcore em idle (1.38–1.5 V por ms) são normais e seguros** — comportamento by-design
  da AMD para bursts; a CPU faz isso centenas de vezes por segundo.

### Leitura de tensão: SVI2 TFN, sempre
Use **HWiNFO "CPU Core Voltage (SVI2 TFN)"** ou o **LibreHardwareMonitor** (equivalente) — é a
telemetria direta do VRM interno do CPU. O "Vcore" do sensor da placa-mãe é menos preciso
(medido por chip externo, com vdroop).

### Limites de potência (PPT/TDC/EDC)
- Stock de CPUs 65 W (5600): **PPT 88 W / TDC 60 A / EDC 90 A**
- Os limites "Motherboard" (auto) estouram isso — cuidado em placas de entrada
- **PPT é o que limita o all-core**: quando o CPU fica preso numa potência fixa, o CO negativo
  converte o mesmo orçamento em mais clock (nos nossos testes: -30 comprou +113 MHz com os
  mesmos 92 W)

## 2. Tensões seguras de plataforma (AM4, uso diário)

| Item | Seguro diário | Limite de risco |
|------|---------------|-----------------|
| Vcore (SVI2 TFN, sob carga) | ≤ FIT individual (~1.25–1.30 V) | >1.325 V é alto |
| VSOC | ≤ 1.10–1.15 V | >1.25 V risco de dano |
| VDDG IOD | ≤ 1.05 V | — |
| VDDG CCD | ≤ 1.00 V | — |
| VDDP | 0.8–1.0 V | — |

Para DDR4-3200/FCLK 1600 (default XMP), deixe VSOC em auto (~1.0–1.1 V).

## 3. Playbook passo a passo

### Fase 0 — Base
1. BIOS atualizada; XMP da RAM habilitado e **estável** (nunca tune CPU e RAM juntos)
2. PBO habilitado na BIOS (`PBO = Advanced` nas Gigabyte)
3. Limites de potência: use os valores atuais (ou PPT ~105 W se quiser mais multi, sabendo que
   sobe temperatura)
4. Scalar: **1** (auto). Scalar alto = boost agressivo = mais potência (anti-eficiência)
5. Anote um baseline: CPU-Z bench + leitura de sensores (clima ambiente estável)

### Fase 1 — Descida all-core com teste A/B
1. Rode `teste-ab.ps1 -OffsetB "-20,-20,-20,-20,-20,-20" -Segundos 120`
2. Compare: clock all-core subiu? temp/potência iguais? WHEA limpo?
3. Suba degrau: -25, depois -30. **-30 é o teto do AGESA.**
4. A cada degrau, rode o **CPU-Z bench** para validar o score — se o score NÃO subir junto com
   o clock, há **clock-stretching** (o offset é agressivo demais e o CPU "estica" o ciclo de
   clock): volte um degrau
5. Sintomas de estouro: WHEA ID 18/19, reboot sem BSOD, freeze em browser

### Fase 2 — Estabilidade de verdade (o teste que importa)
- **CoreCycler** (vem no kit): roda 1 núcleo por vez e pega instabilidade que o teste all-core
  não vê. Comece com o preset rápido (5-10 min/núcleo), depois overnight para a config final
- **Uso real**: 2-3 dias de navegação/vídeo/jogos. CO agressivo demais crasha EM IDLE
- Sleep/wake: teste pelo menos uma vez (nas configs via CLI, o suspend APAGA os offsets —
  configuração definitiva deve estar na BIOS)

### Fase 3 — Refinamento
1. Se algum núcleo falhar (WHEA com APIC ID específico, ou o CoreCycler indicar): alivie
   **só esse núcleo** em +5 (ex.: -30 → -25) e mantenha o resto
2. Os núcleos "melhores" (rank CPPC 0/1, visível no Ryzen Master/HWiNFO) costumam aguentar
   MENOS offset que os piores — é normal o melhor núcleo precisar de -20 e os outros -30
3. Boost Override (+100/+200 MHz): empurra o teto do boost single-thread. +100 é o sweet spot
   de eficiência; +200 comprou +1.9% de ST no caso real. Não afeta o all-core limitado por PPT

### Fase 4 — Gravação definitiva
1. Grave na BIOS: Curve Optimizer por núcleo + Boost Override
2. Reboot + sleep/wake + 1 ciclo rápido do CoreCycler para validar a config persistida

## 4. Armadilhas conhecidas

| Sintoma | Causa provável | Ação |
|---|---|---|
| WHEA ID 18/19 | CO agressivo demais | -5 all-core (ou +5 só no núcleo do APIC ID) |
| Passa stress, crasha em idle | CO tira V da curva inteira (Zen 3) | Aliviar os 2 melhores núcleos |
| Clock sobe mas score não sobe | Clock-stretching | Compare Effective vs Requested Clock; recue |
| Offset "sumiu" após suspender | Comportamento esperado do SMU | Gravar na BIOS (persistent) |
| Erro WHEA de bus/IO + falha em MemTest | Problema de RAM/FCLK, não CO | Não misture os tunings |
| Reboot aleatório sem BSOD | CO ou PSU/VRM | Checar WHEA; em placa de entrada, moderar limites |

## 5. O que NÃO fazer

- Não aplique -30 cego sem teste (o kit existe justamente para testar em degraus)
- Não use "Motherboard limits" em placa de entrada (VRM modesto sem dissipador)
- Não ignore o WHEA "corrigido" — é instabilidade real
- Não tune CPU + RAM + FCLK na mesma sessão
- Não confie em 2 min de teste para a config FINAL — 2 min é para EXPLORAR; a validação final
  é CoreCycler longo + dias de uso real
