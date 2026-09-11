# Beginners Guide — Ryzen CO Toolkit

> Never overclocked or undervolted? This guide is for you. Follow the steps in order, don't skip.

## What you need to know first (1 minute)

- **Curve Optimizer (CO):** an AMD setting that lowers each CPU core's voltage while keeping its frequency.
- **Negative offset (e.g. -25):** the more negative, the less voltage the core requests — less heat, same (or better) performance up to your chip's limit.
- **WHEA (ID 18/19):** an error Windows logs when the CPU silently misbehaves — a sign the offset is too aggressive.
- **Clock-stretching:** the CPU reports a high frequency but delivers less performance — that's why we validate by SCORE, not just "it didn't crash".

## How to open the menu

Open PowerShell in the project folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\menu.ps1
```

You will see a menu with options 1 to 5 plus 0. Follow them in this order.
Option 8 switches the language of the menu and scripts (EN/PT) and saves the choice to scripts/lang.txt.

## Step 1 — Option 1: install everything

1. Choose `1` in the menu and confirm whatever it asks.
2. The menu first downloads the tools (step 1-baixar-ferramentas) then installs the dispatcher (step 2-instalar-dispatcher).
3. When Windows asks for permission (UAC), click **Yes** — this happens **only once**, during setup.
4. The PawnIO installer (`PawnIO_setup.exe`) also asks for UAC: confirm it manually in its own window.
5. If .NET 8 is missing (required by `ryzen-smu-cli`), script 1 already handles roll-forward automatically — just wait for it to finish.

## Step 2 — Option 2: check current state

1. Choose `2`. The menu shows the current offsets (ler-offsets) and the sensors (ler-sensores): temperature, power, SVI2 voltage, and clocks.
2. Write the numbers down — that's your baseline for later comparison.

## Step 3 — Option 3: apply an offset

1. Choose `3`, type the offsets when asked, and confirm with `Y` (`N` applies nothing).
2. Start conservative: `-15` on all cores.
3. Then try -20, -25, -30 in steps of 5, never all at once.

## Step 4 — Option 4: test (A/B test)

1. Choose `4`, enter OffsetB and seconds when asked, confirm with `Y` (`N` cancels).
2. The test compares your current offset (phase A) against OffsetB (phase B) under the same load.
3. Note: phase B leaves OffsetB applied **temporarily** — rebooting the PC restores the BIOS value. That's normal.
4. Compare the SCORES of both phases (e.g. CPU-Z multi/single), not just "crashed or not".

## Step 5 — Option 5: check for WHEA errors

1. Choose `5`. The menu shows whether any WHEA errors happened (checar-whea).
2. If you see **WHEA ID 18 or 19**, your offset is too aggressive: back off **5 points** (e.g. from -30 to -25).
3. Zero WHEA + better score = you may go 5 points further. WHEA or worse score = back off.
4. To find out WHICH core fails, use menu option `7` (CoreCycler + Prime95: Quick ~4-6 min/core; Full takes hours; back off 5 points only on the failing core via option 3).

## Step 6 — Option 0: exit and save to BIOS

1. Choose `0` to exit.
2. After 2-3 days of real-world use with no WHEA and no crashes, **save the best offset in the BIOS** (the CLI is temporary — reboot wipes it).

## If something goes wrong (troubleshooting)

| Problem | What to do |
|---|---|
| A UAC window pops up | Click Yes. Expected once during setup (option 1). |
| Missing DLL error | Run option `1` again (step 1 downloads/installs everything). |
| Offsets reset after reboot | Normal — the CLI is temporary. Save to BIOS to make it stick. |
| WHEA ID 18/19 | Back off 5 points (or +3 on the failing core, via the event's APIC ID). |
| Crash at idle/light load | Classic sign of aggressive CO — back off 5 points and validate 2-3 days of real use. |
| Score dropped without a crash | Silent clock-stretching — back off 5 points. |
| **Never tune CPU and RAM at the same time** | Finish the CPU first, only then touch RAM. |
