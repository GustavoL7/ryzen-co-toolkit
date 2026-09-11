# Ryzen CO Toolkit — Efficiency tuning for AMD Ryzen via Curve Optimizer (CLI)

> [🇧🇷 Português](README.pt-BR.md) | English

> PowerShell scripts + a field-validated method for **undervolting via Curve Optimizer (CO)**
> on **AMD Ryzen** CPUs — tested end-to-end on a real **Ryzen 5 5600** (Zen 3).
> Goal: **same or better performance with less voltage, less heat, and zero extra watts**.

> 📘 **New here? Start with the [Beginners Guide](docs/beginners-guide.md).**

⚠️ **Disclaimer**: touching CPU registers can cause freezes/reboots. Nothing here permanently
alters hardware (CLI-applied CO offsets are **volatile** — reboot/suspend restores the BIOS
values), but use at your own risk. We are not liable for instability or degradation.

---

## Real-world results (Ryzen 5 5600, Gigabyte B450M S2H)

| Config | CPU-Z ST | CPU-Z MT | All-core | SVI2 | Tctl | PPT |
|---|---|---|---|---|---|---|
| Stock | 599 | 4674 | — | — | — | — |
| BIOS CO -15 + BO +100 (start) | 629 | 4675 | ~4.3 GHz | 1.087 V | 65.9 °C | 92.2 W |
| CLI CO -20 → -25 (+100) | — | — | 4.29 → 4.34 GHz | ~1.08 V | ~66 °C | 92.2 W |
| CLI CO -30, AGESA max (+100) | 631 | 4845 | ~4.4 GHz | 1.075 V | 65.0 °C | 92.2 W |
| **FINAL: BIOS CO -30 + BO +200** | **641** | **4843** | 4.45 GHz | 1.104 V | 66.5 °C | 92.2 W |

**+3.6% MT, +7.0% ST vs stock at the SAME power.** Zero WHEA. Details: [`docs/caso-real.md`](docs/caso-real.md) (PT-BR).

### Auto-tune validation (2026-09-11, menu option 6, BIOS CO -30 + BO +200)

PPT pegged at 92.2 W on every step. Zero WHEA.

| Step (all-core) | Tctl | ΔT | Effect. clock | Δclk | Stretch | Verdict |
|---|---|---|---|---|---|---|
| -5 | 67.9 °C | — | 3959 MHz | — | 100.1% | ✅ PASS |
| -10 | 68.5 °C | +0.6 | 3983 MHz | +24 | 100% | ✅ PASS |
| -15 | 68.6 °C | +0.1 | 4045 MHz | +62 | 99.9% | ✅ PASS |
| -20 | 69.0 °C | +0.4 | 4122 MHz | +77 | 100.1% | ✅ PASS |
| -25 | 69.0 °C | ±0 | 4176 MHz | +54 | 99.9% | ✅ PASS |
| **-30 (best)** | 69.1 °C | +0.1 | 4226 MHz | +50 | 100% | ✅ **PASS** |

**+267 MHz for +1.2 °C from -5 to -30 at the same power** — less voltage converts into more clock within the same budget.

---

## What this kit does

1. **Downloads the tools** (CoreCycler, ryzen-smu-cli, LibreHardwareMonitor) from official sources, hash-verified
2. **Installs an elevated dispatcher** via Task Scheduler (`PBO-Runner`) — you confirm the UAC prompt **once**, then every command runs without new elevations
3. **Reads the current CPU state** (active CO offsets, PBO scalar, sensors: temp, power, SVI2, clocks)
4. **Applies per-core CO offsets** from the command line (overrides BIOS until reboot)
5. **Runs an A/B test**: same synthetic load with offset X vs Y, telemetry during load + WHEA check
6. At the end, you **save the winning configuration in the BIOS** (persistent)

## Compatibility

| Generation | Status | What changes |
|---|---|---|
| **Zen 3 (Ryzen 5000 / Vermeer)** | ✅ **Validated end-to-end** (real case: R5 5600) | nothing |
| Zen+ / Zen 2 (1000-3000) | ⚠️ Partial | No official CO (equivalent is PBO + offset/LLC); telemetry and burn test work |
| **Zen 4 (7000) / Zen 5 (9000)** | ⚠️ Adaptable — not tested here | See below |

**What is generic vs CPU-specific:**

- **Generic (works on any generation)**: the elevated dispatcher (Task Scheduler), telemetry via
  LibreHardwareMonitor (temp, power, SVI2, Effective Clocks), the A/B load test, the WHEA check,
  and the **method itself** (-5 steps, validate by score, validate idle/real-world use)
- **CPU-specific**: **writing offsets to the SMU**. `ryzen-smu-cli` was tested on Zen 3 — on
  Zen 4/5 the SMU addresses/arguments change and CO behavior differs (Zen 4/5 adds Curve Shaper,
  which splits the curve by temperature/frequency band, plus a dedicated thermal limit)
- **CoreCycler** (bundled in the kit) officially supports Zen 4/5 already (larger offset range,
  `-50` startValue for Zen 7000+)

**Every CPU is a "silicon lottery"** — the offsets that worked on our 5600 are not a recipe
(not even for another 5600). The value is the method: start conservative (-15), step in -5
increments, validate by score + WHEA + days of real use.

> 🤖 **Using AI to adapt it to your CPU**: the process is highly specifiable for an AI agent.
> Give your assistant: (1) your exact CPU model and generation, (2) this repo as context,
> (3) permission to run the scripts. Tasks the AI must resolve per generation: which tool
> writes CO (Zen 3: `ryzen-smu-cli`; Zen 4/5: `SMUDebugTool` or BIOS), offset range per
> generation, and how to read PowerTable addresses for your SMU
> ([SMUDebugTool](https://github.com/irusanov/SMUDebugTool) lists PMTs per family).
> On Zen 4/5, the safest route may be simply setting CO in the BIOS and using this kit for
> telemetry + A/B testing + validation only.

## Requirements

- Windows 10/11 x64
- AMD Zen 3 CPU (Ryzen 5000 / Vermeer) — validated; other generations see "Compatibility"
- Administrator account (UAC shows up 1x during dispatcher installation)
- .NET 8+ runtime (PawnIO installer and ryzen-smu-cli need it; the script patches roll-forward automatically)
- BIOS with PBO enabled (most B450/B550/X570 boards have it; Gigabyte path: `Advanced → AMD Overclocking → Precision Boost Overdrive → PBO = Advanced`)

## Quickstart

```powershell
# 1. Clone the repo
git clone <repo-url>
cd ryzen-co-toolkit

# 2. Download the tools (no admin needed)
powershell -ExecutionPolicy Bypass -File scripts\1-baixar-ferramentas.ps1

# 3. Install the dispatcher (UAC 1x)
powershell -ExecutionPolicy Bypass -File scripts\2-instalar-dispatcher.ps1

# 4. Current CPU state
powershell -ExecutionPolicy Bypass -File scripts\ler-offsets.ps1
powershell -ExecutionPolicy Bypass -File scripts\ler-sensores.ps1

# 5. A/B test: current offset vs -25 all-core, 2 min load per phase
powershell -ExecutionPolicy Bypass -File scripts\teste-ab.ps1 -OffsetB "-25,-25,-25,-25,-25,-25"

# 5b. Apply a specific offset set directly + check WHEA history
powershell -ExecutionPolicy Bypass -File scripts\aplicar-offsets.ps1 -Offsets "-30,-30,-30,-30,-30,-30"
powershell -ExecutionPolicy Bypass -File scripts\checar-whea.ps1 -Minutos 120

# 6. After testing, SAVE the best offset in the BIOS (the CLI is volatile!)
```

## How the dispatcher works (why UAC only once)

The tools (SMU, sensors) require **Administrator execution**. Instead of confirming UAC on
every command, the kit registers a **scheduled task** (`PBO-Runner`) with `RunLevel Highest`:

```
exec.ps1  ← reads the command from cmd.txt, executes elevated, writes output to logs\out.txt
```

From then on, any kit script triggers it via `Start-ScheduledTask` **with no new UAC prompt**.
If the machine crashes/reboots mid-test, just restart: offsets go back to the BIOS values.

## Important warnings (read the full guide — PT-BR)

- **There is no 1.2 V degradation limit for Zen 3** — the real limit is the chip's individual
  FIT voltage (typically 1.25–1.30 V under load). Undervolting via negative CO is safe by design.
  Full guide: [`docs/guia-completo.md`](docs/guia-completo.md)
- **CO -30 is the AGESA floor**; beyond that only per-core positive offsets
- The classic failure mode of aggressive CO is **crash at idle/light load** (not under stress) —
  validate 2-3 days of real use before calling it done
- **Validate by SCORE, not just "didn't crash"**: an aggressive-enough-to-fail CO causes silent
  clock-stretching (compare Effective Clock vs Requested Clock in LibreHardwareMonitor)
- **WHEA-Logger ID 18/19** in Event Viewer = offset too aggressive; back off 5 points (or +3 on
  the failing core — the event's APIC ID tells you which)
- Never tune CPU and RAM at the same time

## Structure

```
├── README.md (EN), README.pt-BR.md, LICENSE
├── exec.ps1         elevated dispatcher entry point (runs via the PBO-Runner task)
├── opencode.json    agent pipeline configuration
├── .opencode/       pipeline specs and memory
├── docs/            guia-completo.md, caso-real.md, fontes.md (PT-BR, with dated sources)
├── scripts/         tool downloader, dispatcher installer, sensors, offsets, aplicar-offsets, A/B test, WHEA (checar-whea)
├── tools/           (gitignored) binaries downloaded by script 1
└── logs/            (gitignored) test outputs
```

## Third-party tool credits

| Tool | Author | License |
|---|---|---|
| [CoreCycler](https://github.com/sp00n/CoreCycler) | sp00n | GPL-3.0 |
| [ryzen-smu-cli](https://github.com/rawhide-kobayashi/ryzen-smu-cli) | rawhide-kobayashi | GPL-3.0 |
| [LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor) | LibreHardwareMonitor team | MPL-2.0 |
| [PawnIO](https://pawnio.eu/) | namazso | LGPL-3.0 |
| [PowerShell.HardwareMonitor](https://github.com/Lifailon/PowerShell.HardwareMonitor) | Lifailon | MIT |

This project redistributes none of them — `scripts\1-baixar-ferramentas.ps1` downloads straight
from the official sources.
