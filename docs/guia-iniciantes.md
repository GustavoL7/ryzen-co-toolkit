# Guia para Iniciantes — Ryzen CO Toolkit

> Nunca mexeu com overclock/undervolt? Este guia e para voce. Siga os passos na ordem, sem pular.

## O que voce precisa saber antes (1 minuto)

- **Curve Optimizer (CO):** ajuste da BIOS/driver da AMD que reduz a tensao de cada nucleo do CPU mantendo a frequencia.
- **Offset negativo (ex.: -25):** quanto mais negativo, menos tensao o nucleo pede — menos calor, mesma (ou maior) performance ate o limite do chip.
- **WHEA (ID 18/19):** erro registrado pelo Windows quando o CPU falha silenciosamente — sinal de que o offset esta agressivo demais.
- **Clock-stretching:** o CPU finge que roda na frequencia alta, mas entrega menos performance — por isso validamos por SCORE, nao so por "nao travou".

## Como abrir o menu

Abra o PowerShell na pasta do projeto e rode:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\menu.ps1
```

Voce vera um menu com as opcoes 1 a 5 e 0. Siga nesta ordem.
A opcao 8 alterna o idioma do menu e dos scripts (PT/EN) e salva a escolha em scripts/lang.txt.

## Passo 1 — Opcao 1: instalar tudo

1. Escolha `1` no menu e confirme o que ele pedir.
2. O menu primeiro baixa as ferramentas (passo 1-baixar-ferramentas) e depois instala o dispatcher (passo 2-instalar-dispatcher).
3. Quando o Windows pedir permissao (UAC), clique em **Sim** — isso acontece **1 vez so** na instalacao.
4. O instalador do PawnIO (`PawnIO_setup.exe`) tambem pede UAC: confirme manualmente na janela dele.
5. Se faltar .NET 8 (necessario para o `ryzen-smu-cli`), o script 1 ja ajusta o roll-forward sozinho — so aguarde terminar.

## Passo 2 — Opcao 2: ver o estado atual

1. Escolha `2`. O menu mostra os offsets atuais (ler-offsets) e os sensores (ler-sensores): temperatura, potencia, tensao SVI2 e clocks.
2. Anote os numeros — esse e o seu ponto de partida para comparar depois.

## Passo 3 — Opcao 3: aplicar um offset

1. Escolha `3`, digite os offsets quando pedido e confirme com `S` (com `N` ele nao aplica nada).
2. Comece conservador: `-15` em todos os nucleos.
3. Teste -20, -25, -30 em degraus de 5, nunca de uma vez.

## Passo 4 — Opcao 4: testar (teste A/B)

1. Escolha `4`, informe o OffsetB e os segundos quando pedido, confirme com `S` (`N` cancela).
2. O teste compara seu offset atual (fase A) com o OffsetB (fase B) sob a mesma carga.
3. Atencao: a fase B deixa o OffsetB aplicado de forma **volatil** — se reiniciar o PC, volta ao valor da BIOS. Isso e normal.
4. Compare os SCORES das duas fases (ex.: CPU-Z multi/single), nao apenas "travou ou nao".

## Passo 5 — Opcao 5: checar erros WHEA

1. Escolha `5`. O menu mostra se houve erros WHEA (checar-whea).
2. Se aparecer **WHEA ID 18 ou 19**, seu offset esta agressivo: recue **5 pontos** (ex.: de -30 para -25).
3. Zero WHEA + score melhor = pode avancar 5 pontos. WHEA ou score pior = recue.
4. Para descobrir QUAL nucleo falha, use a opcao `7` do menu (CoreCycler + Prime95: Rapido ~4-6 min/nucleo; Completo leva horas; quem falhar, recue 5 pontos so nele via opcao 3).

## Passo 6 — Opcao 0: sair e gravar na BIOS

1. Escolha `0` para sair.
2. Depois de 2-3 dias de uso real sem WHEA nem travamento, **grave o melhor offset na BIOS** (o CLI e volatil — reboot apaga).

## Se der erro (troubleshooting)

| Problema | O que fazer |
|---|---|
| Janela de UAC aparece | Clique em Sim. E esperado 1x na instalacao (opcao 1). |
| Erro de DLL ausente | Rode a opcao `1` de novo (passo 1 baixa/instala tudo). |
| Offsets voltaram apos reboot | Normal — o CLI e volatil. Grave na BIOS para fixar. |
| WHEA ID 18/19 | Recue 5 pontos no offset (ou +3 no nucleo culpado, pelo APIC ID do evento). |
| Travou em idle/uso leve | Classico de CO agressivo — recue 5 pontos e valide 2-3 dias de uso real. |
| Score caiu mesmo sem travar | Clock-stretching silencioso — recue 5 pontos. |
| **Nunca tune CPU e RAM ao mesmo tempo** | Termine o CPU primeiro, so depois mexa na RAM. |
