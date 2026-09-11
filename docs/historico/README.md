# Histórico — sessão 2026-09-09 (arquivado, NÃO executar)

Scripts da sessão original de tuning num Ryzen 5 5600 (2026-09-09), movidos de
`scripts/sessao-2026-09-09/` para cá na fase E do improve-all.

**Por que arquivado:** todos têm paths hardcoded para `C:\Workspace\tools-pbo\`
(layout antigo, fora deste repo). Estão mortos no layout atual (`tools/` e
`logs/` na raiz, via `scripts/1-baixar-ferramentas.ps1`).

**Não corrigir os paths nem reativar** — valor é só histórico (ver os comandos
SMU e a sequência de passes usados na sessão validada). O fluxo atual e
suportado está em `scripts/` (ler/aplicar-offsets, ler-sensores, teste-ab,
checar-whea) e no `docs/caso-real.md`.
