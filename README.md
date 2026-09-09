# Zen3 CO Toolkit — Tuning de eficiência para Ryzen 5000 (Curve Optimizer via CLI)

> Kit de scripts PowerShell + método validado para **undervolt via Curve Optimizer (CO)** em
> **AMD Ryzen 5000 (Zen 3 / Vermeer)** — testado de ponta a ponta num **Ryzen 5 5600** real.
> Objetivo: **mesma ou mais performance com menos tensão, menos temperatura e nenhum watt extra**.

⚠️ **Disclaimer**: mexer em registradores do CPU pode causar travamentos/reboots. Nada aqui altera
hardware permanentemente (os offsets aplicados via CLI são **voláteis** — reboot/suspend restauram
a BIOS), mas use por sua conta e risco. Não nos responsabilizamos por instabilidade ou degradação.

---

## Resultado real (Ryzen 5 5600, Gigabyte B450M S2H, sessão de 2026-09-09)

| Config | CPU-Z Single | CPU-Z Multi | Clock all-core | Vcore (SVI2) | Temp Tctl | Potência |
|---|---|---|---|---|---|---|
| Ponto de partida (BIOS, CO -15) | 629 | 4675 | 4275-4350 MHz | 1.087 V | 65.9 °C | 92.2 W |
| CO -20 (CLI) | — | — | 4288 MHz | 1.075 V | 65.8 °C | 92.2 W |
| CO -25 (CLI) | — | — | 4342 MHz | 1.087 V | 65.9 °C | 92.2 W |
| CO -30 (CLI, máx AGESA) | 631 | 4845 | 4388-4425 MHz | 1.075 V | 65.0 °C | 92.2 W |
| **FINAL: BIOS CO -30 + Boost Override +200** | **641** | **4843** | 4450 MHz | 1.104 V | 66.5 °C | 92.2 W |

**+3.6% multi e +1.9% single com o MESMO consumo e temperatura.** Zero erros WHEA em todos os
passos. Detalhes completos em [`docs/caso-real.md`](docs/caso-real.md).

---

## O que este kit faz

1. **Baixa as ferramentas** necessárias (CoreCycler, ryzen-smu-cli, LibreHardwareMonitor) com hash verificado
2. **Instala um dispatcher elevado** via Task Scheduler (`PBO-Runner`) — você confirma o UAC **uma vez** e depois todos os comandos rodam sem pedir elevation de novo
3. **Lê o estado atual** do CPU (offsets CO ativos, scalar, sensores: temp, potência, SVI2, clocks)
4. **Aplica offsets CO por núcleo** via linha de comando (sobrepõe a BIOS até reboot)
5. **Roda teste A/B**: mesma carga sintética com offset X vs Y, telemetria durante a carga + checagem de WHEA
6. Ao final, você **grava a configuração vencedora na BIOS** (persistente)

## Requisitos

- Windows 10/11 x64
- CPU AMD Zen 3 (Ryzen 5000 / Vermeer) — os offsets CO via SMU funcionam nessa família
- Conta de administrador (o UAC aparece 1x na instalação do dispatcher)
- .NET 8+ runtime (o installer do PawnIO e o ryzen-smu-cli precisam; o script ajusta o roll-forward automaticamente)
- BIOS com PBO habilitado (a maioria das B450/B550/X570 tem; caminho Gigabyte: `Advanced → AMD Overclocking → Precision Boost Overdrive → PBO = Advanced`)

## Quickstart

```powershell
# 1. Clone o repo
git clone <url-do-repo>
cd zen3-co-toolkit

# 2. Baixa as ferramentas (nao precisa de admin)
powershell -ExecutionPolicy Bypass -File scripts\1-baixar-ferramentas.ps1

# 3. Instala o dispatcher (UAC 1x)
powershell -ExecutionPolicy Bypass -File scripts\2-instalar-dispatcher.ps1

# 4. Estado atual do CPU
powershell -ExecutionPolicy Bypass -File scripts\ler-offsets.ps1
powershell -ExecutionPolicy Bypass -File scripts\ler-sensores.ps1

# 5. Teste A/B: offset atual vs -25 all-core, 2 min de carga por fase
powershell -ExecutionPolicy Bypass -File scripts\teste-ab.ps1 -OffsetB "-25,-25,-25,-25,-25,-25"

# 6. Apos os testes, GRAVE o melhor offset na BIOS (o CLI e volatil!)
```

## Como funciona o dispatcher (por que UAC 1x)

As ferramentas (SMU, sensores) exigem **execução como Administrador**. Em vez de confirmar o UAC
a cada comando, o kit registra uma **tarefa agendada** (`PBO-Runner`) com `RunLevel Highest`:

```
scripts\exec.ps1  ← lê o comando de cmd.txt, executa elevado, grava saída em logs\out.txt
```

Daí em diante, qualquer script do kit dispara via `Start-ScheduledTask` **sem novo UAC**.
Se travar/rebootar no meio de um teste, é só reiniciar: os offsets voltam pros da BIOS.

## Avisos importantes (leia o guia completo)

- **Não existe limite de 1.2 V para o Zen 3** — o limite real é o FIT individual do chip (típico 1.25–1.30 V sob carga). Undervolt via CO negativo é seguro por design. [`docs/guia-completo.md`](docs/guia-completo.md)
- **CO -30 é o teto do AGESA**; acima disso é só com offset positivo em núcleos específicos
- O modo de falha clássico do CO agressivo é **crash em idle/carga leve** (não em stress) — valide 2-3 dias de uso real antes de considerar pronto
- **Valide por SCORE, não só por "não crashou"**: CO agressivo demais causa clock-stretching silencioso (compare Effective Clock vs Requested Clock no LibreHardwareMonitor)
- Erros **WHEA-Logger ID 18/19** no Event Viewer = offset agressivo demais; recue 5 pontos (ou +3 no núcleo culpado — o APIC ID do evento aponta qual)
- Nunca tune CPU e RAM ao mesmo tempo

## Estrutura

```
├── README.md, LICENSE
├── docs/            guia-completo.md, caso-real.md, fontes.md
├── scripts/         baixar-ferramentas, instalar-dispatcher, sensores, offsets, teste A/B, WHEA
├── tools/           (gitignored) binarios baixados pelo script 1
└── logs/            (gitignored) saidas de teste
```

## Créditos das ferramentas de terceiros

| Ferramenta | Autor | Licença |
|---|---|---|
| [CoreCycler](https://github.com/sp00n/CoreCycler) | sp00n | GPL-3.0 |
| [ryzen-smu-cli](https://github.com/rawhide-kobayashi/ryzen-smu-cli) | rawhide-kobayashi | GPL-3.0 |
| [LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor) | LibreHardwareMonitor team | MPL-2.0 |
| [PawnIO](https://pawnio.eu/) | namazso | LGPL-3.0 |
| [PowerShell.HardwareMonitor](https://github.com/Lifailon/PowerShell.HardwareMonitor) | Lifailon | MIT |

Este projeto não redistribui nenhum deles — o script `1-baixar-ferramentas.ps1` baixa direto das fontes oficiais.
