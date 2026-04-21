@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Abrir HTML local via HTTP (porta fixa 8787)

:: ============================================================
:: CONFIGURAÇÃO
:: ============================================================
set "PORT=8787"
cls
echo ================================================
echo ABRIR PAGINA HTML LOCAL VIA HTTP
echo ================================================
echo.
set /p "FILE_TO_OPEN=Digite o caminho completo do arquivo HTML: "

:: Remover aspas se o usuário colou com aspas
set "FILE_TO_OPEN=%FILE_TO_OPEN:"=%"

:: ============================================================
:: VALIDACAO
:: ============================================================
if "%FILE_TO_OPEN%"=="" (
    echo.
    echo [ERRO] Nenhum caminho foi informado.
    timeout /t 2 >nul
    exit /b 1
)

if not exist "%FILE_TO_OPEN%" (
    echo.
    echo [ERRO] O arquivo informado nao existe:
    echo "%FILE_TO_OPEN%"
    timeout /t 4 >nul
    exit /b 1
)

for %%I in ("%FILE_TO_OPEN%") do (
    set "HTML_DIR=%%~dpI"
    set "HTML_NAME=%%~nxI"
)

:: ============================================================
:: ENCODAR NOME DO ARQUIVO PARA URL
:: ============================================================
for /f "usebackq delims=" %%U in (`
    powershell -NoProfile -Command "[uri]::EscapeDataString('%HTML_NAME%')"
`) do (
    set "HTML_NAME_URL=%%U"
)

:: ============================================================
:: DESCOBRIR PYTHON
:: ============================================================
set "PY_EXE="

where py >nul 2>nul
if not errorlevel 1 set "PY_EXE=py"

if not defined PY_EXE (
    where python >nul 2>nul
    if not errorlevel 1 set "PY_EXE=python"
)

if not defined PY_EXE (
    echo.
    echo [ERRO] Python nao encontrado no sistema.
    timeout /t 4 >nul
    exit /b 1
)

:: ============================================================
:: MATA PROCESSO QUE ESTEJA USANDO A PORTA 8787
:: ============================================================
echo.
echo Verificando processos na porta %PORT%...

for /f "tokens=5" %%P in ('netstat -ano ^| findstr /c:":%PORT% " ^| findstr LISTENING') do (
    echo Matando processo PID %%P que estava usando a porta %PORT%...
    taskkill /PID %%P /F >nul 2>&1
)

:: pequena pausa
timeout /t 1 >nul

:: ============================================================
:: SUBE SERVIDOR LIMPO NA PASTA DO HTML
:: ============================================================
echo Iniciando servidor HTTP na pasta:
echo "%HTML_DIR%"
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"Start-Process -WindowStyle Hidden -FilePath '%PY_EXE%' -ArgumentList '-m','http.server','%PORT%' -WorkingDirectory '%HTML_DIR%'"

:: pequena pausa para o servidor iniciar
timeout /t 2 >nul

:: ============================================================
:: ABRIR NO NAVEGADOR
:: ============================================================
set "TARGET_URL=http://127.0.0.1:%PORT%/%HTML_NAME_URL%"
echo Abrindo no navegador: %TARGET_URL%
start "" "%TARGET_URL%"

exit /b 0
