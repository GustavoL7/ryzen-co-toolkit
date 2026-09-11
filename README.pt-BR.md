# Ryzen CO Toolkit — Tuning de eficiência para AMD Ryzen (Curve Optimizer via CLI)

> 🇧🇷 Português | [English](README.md)

> Kit de scripts PowerShell + método validado para **undervolt via Curve Optimizer (CO)** em
> **CPUs AMD Ryzen** — testado de ponta a ponta num **Ryzen 5 5600** (Zen 3; veja
> compatibilidade com outras gerações abaixo).
> Objetivo: **mesma ou mais performance com menos tensão, menos temperatura e nenhum watt extra**.

> 📘 **Iniciante? Comece pelo [Guia para Iniciantes](docs/guia-iniciantes.md).**

⚠️ **Disclaimer**: mexer em registradores do CPU pode causar travamentos/reboots. Nada aqui altera
hardware permanentemente (os offsets aplicados via CLI são **voláteis** — reboot/suspend restauram
a BIOS), mas use por sua conta e risco. Não nos responsabilizamos por instabilidade ou degradação.

---

## Resultado real (Ryzen 5 5600, Gigabyte B450M S2H)

| Config | CPU-Z ST | CPU-Z MT | All-core | SVI2 | Tctl | PPT |
|---|---|---|---|---|---|---|
| Stock | 599 | 4674 | — | — | — | — |
| BIOS CO -15 + BO +100 (início) | 629 | 4675 | ~4,3 GHz | 1,087 V | 65,9 °C | 92,2 W |
| CLI CO -20 → -25 (+100) | — | — | 4,29 → 4,34 GHz | ~1,08 V | ~66 °C | 92,2 W |
| CLI CO -30, máx AGESA (+100) | 631 | 4845 | ~4,4 GHz | 1,075 V | 65,0 °C | 92,2 W |
| **FINAL: BIOS CO -30 + BO +200** | **641** | **4843** | 4,45 GHz | 1,104 V | 66,5 °C | 92,2 W |

**+3,6% MT, +7,0% ST vs stock com o MESMO consumo.** Zero WHEA. Detalhes em [`docs/caso-real.md`](docs/caso-real.md).

### Validação auto-tune (2026-09-11, opção 6 do menu, BIOS CO -30 + BO +200)

PPT cravado em 92,2 W em todos os degraus. Zero WHEA.

| Degrau (all-core) | Tctl | ΔT | Clock efet. | Δclk | Stretch | Veredito |
|---|---|---|---|---|---|---|
| -5 | 67,9 °C | — | 3959 MHz | — | 100,1% | ✅ PASS |
| -10 | 68,5 °C | +0,6 | 3983 MHz | +24 | 100% | ✅ PASS |
| -15 | 68,6 °C | +0,1 | 4045 MHz | +62 | 99,9% | ✅ PASS |
| -20 | 69,0 °C | +0,4 | 4122 MHz | +77 | 100,1% | ✅ PASS |
| -25 | 69,0 °C | ±0 | 4176 MHz | +54 | 99,9% | ✅ PASS |
| **-30 (melhor)** | 69,1 °C | +0,1 | 4226 MHz | +50 | 100% | ✅ **PASS** |

**+267 MHz por +1,2 °C de -5 a -30 com a mesma potência** — menos tensão vira mais clock dentro do mesmo orçamento.

---

## O que este kit faz

Tudo roda de um menu interativo (inglês por padrão, opção `8` troca para português):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\menu.ps1
```

| Opção | O que faz |
|---|---|
| 1 - Instalar | Baixa as ferramentas (hash verificado) + registra a tarefa elevada (UAC 1x) |
| 2 - Ver estado | Offsets CO ativos + temperatura/potência/clocks |
| 3 - Aplicar offsets | Offsets manuais por núcleo (com confirmação) |
| 4 - Teste A/B | Mesma carga, offset X vs Y, telemetria + checagem WHEA |
| 5 - Checar WHEA | Histórico de erros de hardware |
| 6 - Ajuste automático ⭐ | Varredura automática (-10/-20/-30, re-testa degraus marginais, refina) com veredito + melhor offset |
| 7 - Afinar por núcleo | Validação CoreCycler por núcleo (para CPUs que falharam na opção 6) |
| 8 - Idioma | English ↔ Português |
| 0 - Sair | |

Ao final, você **grava a configuração vencedora na BIOS** (offsets via CLI são voláteis — reboot restaura a BIOS).

## Compatibilidade

| Geração | Status | O que muda |
|---|---|---|
| **Zen 3 (Ryzen 5000 / Vermeer)** | ✅ **Validado de ponta a ponta** (caso real: R5 5600) | nada |
| Zen+ / Zen 2 (1000-3000) | ⚠️ Parcial | Sem CO oficial (o equivalente é PBO + offset/LLC); telemetria e burn test funcionam |
| **Zen 4 (7000) / Zen 5 (9000)** | ⚠️ Ajustável — não testado aqui | Ver abaixo |

**O que é genérico vs o que é específico por CPU:**

- **Genérico (funciona em qualquer geração)**: o dispatcher elevado (Task Scheduler), a telemetria
  via LibreHardwareMonitor (temp, potência, SVI2, Effective Clocks), o teste A/B de carga, a checagem
  de WHEA, e o **método em si** (degraus de -5, validar por score, validar idle/use real)
- **Específico por CPU**: a **escrita de offsets no SMU**. O `ryzen-smu-cli` foi testado no Zen 3 —
  em Zen 4/5 os endereços/argumentos do SMU mudam e o comportamento do CO também (no Zen 4/5 existe
  Curve Shaper, que divide a curva por banda de temperatura/frequência, além de thermal limit dedicado)
- O **CoreCycler** (incluído no kit) já suporta Zen 4/5 oficialmente (range de offsets maior,
  `-50` como startValue para Zen 7000+)

**Cada CPU é um "chip lottery"** — os offsets que funcionaram no nosso 5600 não são receita
(nem para outro 5600). O método é: partir conservador (-15), testar em degraus, validar por
score + WHEA + dias de uso.

> 🤖 **Usando IA para adaptar ao seu CPU**: o processo é bem especificável para um agente de IA.
> Dê ao seu assistente: (1) o modelo exato do CPU e a geração, (2) este repo como contexto,
> (3) a permissão de executar os scripts. Tarefas que a IA precisa resolver por geração:
> qual ferramenta escreve o CO (Zen 3: `ryzen-smu-cli`; Zen 4/5: `SMUDebugTool` ou BIOS),
> range de offsets por geração, e como ler os endereços do PowerTable no seu SMU
> ([SMUDebugTool](https://github.com/irusanov/SMUDebugTool) lista os PMTs por família).
> Em Zen 4/5 o mais seguro pode ser simplesmente gravar o CO na BIOS e usar o kit só para
> telemetria + teste A/B + validação.

## Requisitos

- Windows 10/11 x64
- CPU AMD Zen 3 (Ryzen 5000 / Vermeer) — validado; outras gerações veja "Compatibilidade"
- Conta de administrador (o UAC aparece 1x na instalação do dispatcher)
- .NET 8+ runtime (o installer do PawnIO e o ryzen-smu-cli precisam; o script ajusta o roll-forward automaticamente)
- BIOS com PBO habilitado (a maioria das B450/B550/X570 tem; caminho Gigabyte: `Advanced → AMD Overclocking → Precision Boost Overdrive → PBO = Advanced`)

## Quickstart

```powershell
# 1. Clone o repo
git clone <repo-url>
cd ryzen-co-toolkit

# 2. Abra o menu e siga as opções 1 → 2 → 6
powershell -ExecutionPolicy Bypass -File scripts\menu.ps1

# 3. Apos os testes, GRAVE o melhor offset na BIOS (o CLI e volatil!)
```

Prefere rodar os scripts direto? Cada opção do menu corresponde 1:1 a um script em
`scripts/` (ver tabela acima). Fluxo manual: `1-baixar-ferramentas.ps1` →
`2-instalar-dispatcher.ps1` → `ler-offsets.ps1` / `ler-sensores.ps1` →
`auto-tune.ps1` (ou `teste-ab.ps1 -OffsetB "-25,-25,-25,-25,-25,-25"`).

## Como funciona o dispatcher (por que UAC 1x)

As ferramentas (SMU, sensores) exigem **execução como Administrador**. Em vez de confirmar o UAC
a cada comando, o kit registra uma **tarefa agendada** (`PBO-Runner`) com `RunLevel Highest`:

```
exec.ps1  ← lê o comando de cmd.txt, executa elevado, grava saída em logs\out.txt
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
├── README.md (EN), README.pt-BR.md, LICENSE
├── exec.ps1         ponto de entrada do dispatcher elevado (roda via tarefa PBO-Runner)
├── opencode.json    configuracao do pipeline de agentes
├── .opencode/       specs do pipeline e memoria
├── docs/            guia-completo.md, caso-real.md, fontes.md
├── scripts/         menu, ajuste-automatico, validacao-por-nucleo, baixar-ferramentas, instalar-dispatcher, sensores, offsets, teste A/B, WHEA, lib/ (elevacao, idioma)
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
