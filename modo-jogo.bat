@echo off
rem modo-jogo.bat - aplica mix gaming validado via PBO-Runner sem UAC
rem Uso com duplo-clique. Requer menu opcao 1 executada uma vez.
rem Mix R5 5600 6C validado em 25-09-2026 (sweet B, screening 60s + Tarkov/Arena). Para outro CPU ajuste a
rem quantidade de valores no CSV e valide por score mais WHEA.
setlocal
set "ROOT=%~dp0"
set "EXE=%ROOT%tools\ryzen-smu-cli\ryzen-smu-cli.exe"
set "CMD=%ROOT%cmd.txt"
set "OUT=%ROOT%logs\out.txt"

schtasks /Query /TN PBO-Runner >NUL 2>NUL
if errorlevel 1 goto NO_TASK
if not exist "%EXE%" goto NO_EXE
if not exist "%ROOT%logs" mkdir "%ROOT%logs" >NUL 2>NUL
if exist "%OUT%" del "%OUT%"
>"%CMD%" echo "%EXE%" --offset -28,-27,-29,-27,-29,-27
schtasks /Run /TN PBO-Runner >NUL 2>NUL
echo Aguardando PBO-Runner - modo jogo...
set /a TRIES=30
:POLL
ping -n 3 127.0.0.1 >NUL 2>NUL
if not exist "%OUT%" goto NEXT_POLL
type "%OUT%" 2>NUL | findstr /C:"=== EXIT" >NUL
if not errorlevel 1 goto DONE
:NEXT_POLL
set /a TRIES-=1
if %TRIES% LEQ 0 goto TIMEOUT
goto POLL
:DONE
type "%OUT%"
echo.
echo Modo jogo aplicado - volatil - reboot restaura a BIOS.
goto END
:NO_TASK
echo PBO-Runner ausente. Rode o menu opcao 1 uma vez e tente de novo.
exit /b 1
:NO_EXE
echo ryzen-smu-cli.exe ausente. Rode o menu opcao 1 uma vez e tente de novo.
exit /b 1
:TIMEOUT
echo Tempo esgotado aguardando o PBO-Runner - logs\out.txt sem === EXIT em 60s.
exit /b 1
:END
