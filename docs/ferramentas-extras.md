# Ferramentas extras (sem brigar com o Curve Optimizer)

> Nenhuma ferramenta aqui escreve CO nem mexe no SMU. Elas medem, limpam
> memoria ou ajustam timer/plano de energia — convivem com o ajuste do kit.

## TOP 5 sem conflito

| # | Ferramenta | Pra que serve | Quando usar |
|---|---|---|---|
| 1 | HWiNFO64 | Monitorar temp, clocks, SVI2, WHEA | Sempre (diagnostico) |
| 2 | CapFrameX + Cinebench | Medir score/FPS e 1% lows | Validar ganho do CO (opcao 4/6) |
| 3 | ISLC + TimerTool | Limpar standby list, fixar timer 0.5 ms | Stutter apos idle longo |
| 4 | ParkControl | Desestacionar nucleos (100%) | Latencia alta ao acordar nucleo |
| 5 | Bitsum Highest Performance | Plano de energia pronto p/ latencia | Alternativa ao Equilibrado |

Rode a opcao 9 do menu (`checar-os.ps1`) para ver o estado atual
(plano ativo, timer, parking, standby, ferramentas detectadas).

## Aplicar pelo menu (opcao 9)

A opcao 9 mostra o check e pergunta se aplica: sobe para Alto
desempenho (se estava em Economia/Equilibrado) + unpark 100% em AC+DC.
O timer 0.5 ms continua manual (abra o ISLC). Reversao: rode
`powercfg /setactive SCHEME_BALANCED` e volte o unpark com CPMINCORES 0.

## Limites PBO (PPT/TDC/EDC)

A opcao 2 do menu mostra os limites via `ler-pbo.ps1` (somente leitura).
Na versao atual do ryzen-smu-cli nao ha getter de limites SMU
(`--get-pbo-limits` desconhecido) — o script informa isso e sai normal;
use o PPT atual dos sensores + os limites exatos no HWiNFO64.
Histórico 19/09: SMUDebugTool v1.41 testado no Vermeer — aba PBO sem campos
de limites (só CO+FMax); removido do kit — limites em runtime via Ryzen Master.

## O que EVITAR junto

Nao rode por cima do CO do kit (conflito de escrita no SMU / PBO):

- Ryzen Master (reescreve CO/PBO por conta propria)
- PBO2 Tuner / Hydra (outro escritor de CO — escolha UM)
- SMUDebug por cima (leitura ok, escrita junto nao)
- Dois fixadores de timer ao mesmo tempo (ISLC **ou** TimerTool)

## Risco / categoria

| Categoria | Exemplos | Risco |
|---|---|---|
| Somente leitura | HWiNFO64, checar-os, checar-whea | Nenhum |
| Limpeza / timer | ISLC, TimerTool, ParkControl, plano Bitsum | Baixo (reversivel) |
| Escrita CO/SMU | Ryzen Master, PBO2/Hydra, SMUDebug escrita | Alto (conflita com o kit) |

Regra de ouro: **um escritor de CO por vez** (o kit **ou** outro).
Monitorar pode quantos quiser.

---

## EN (short)

Extra tools that do not fight your CO: HWiNFO64 (sensors), CapFrameX +
Cinebench (score), ISLC/TimerTool (standby + 0.5 ms timer), ParkControl
(unpark 100%), Bitsum HP power plan. Avoid stacking CO writers
(Ryzen Master, PBO2/Hydra, SMUDebug writes) on top of the kit.
Rule: one CO writer at a time; monitors are free. Run menu option 9
(`checar-os.ps1`) for a read-only status.

## Apply via menu (option 9)

Option 9 shows the check and asks before applying: raises to High
performance (if on Power Saver/Balanced) + 100% unpark on AC+DC.
The 0.5 ms timer stays manual (open ISLC). Revert with
`powercfg /setactive SCHEME_BALANCED` plus CPMINCORES 0 unpark.

## PBO limits (PPT/TDC/EDC)

Menu option 2 shows limits via `ler-pbo.ps1` (read-only).
The current ryzen-smu-cli has no SMU limits getter
(`--get-pbo-limits` unknown) — the script says so and exits clean;
use the live PPT from sensors + the exact limits in HWiNFO64.
History 09-19: SMUDebugTool v1.41 tested on Vermeer — PBO tab with no limit
fields (CO+FMax only); removed from the kit — runtime limits via Ryzen Master.
