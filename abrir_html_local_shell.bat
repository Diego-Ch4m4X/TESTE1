@echo off
setlocal EnableExtensions DisableDelayedExpansion
title ABRIR PAGINA HTML LOCAL VIA HTTP (OCULTO)

rem ============================================================
rem CONFIG
rem ============================================================
set "PORT=8787"
set "LOG_FILE=%TEMP%\serve_html_local_8787.log"
set "SELF_BAT=%~f0"
set "PWSH_LAUNCHER=%TEMP%\serve_html_local_8787_hidden.vbs"

cls
echo ================================================
echo  ABRIR PAGINA HTML LOCAL VIA HTTP (OCULTO)
echo ================================================
echo.

set /p "FILE_TO_OPEN=Digite o caminho completo do arquivo HTML: "
set "FILE_TO_OPEN=%FILE_TO_OPEN:"=%"

if "%FILE_TO_OPEN%"=="" (
    echo.
    echo [ERRO] Nenhum caminho foi informado.
    echo.
    pause
    exit /b 1
)

if not exist "%FILE_TO_OPEN%" (
    echo.
    echo [ERRO] O arquivo informado nao existe:
    echo "%FILE_TO_OPEN%"
    echo.
    pause
    exit /b 1
)

for %%I in ("%FILE_TO_OPEN%") do (
    set "HTML_DIR=%%~dpI"
    set "HTML_NAME=%%~nxI"
)

echo.
echo Verificando processos ocupando a porta %PORT%...
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /r /c:":%PORT% .*LISTENING"') do (
    taskkill /PID %%P /F >nul 2>&1
)

timeout /t 1 /nobreak >nul

set "SERVE_HTML_DIR=%HTML_DIR%"
set "SERVE_HTML_NAME=%HTML_NAME%"
set "SERVE_HTML_PORT=%PORT%"
set "SERVE_HTML_LOG=%LOG_FILE%"
set "SERVE_HTML_SELF=%SELF_BAT%"

if exist "%LOG_FILE%" del /f /q "%LOG_FILE%" >nul 2>&1
if exist "%PWSH_LAUNCHER%" del /f /q "%PWSH_LAUNCHER%" >nul 2>&1

> "%PWSH_LAUNCHER%" echo Set oShell = CreateObject("WScript.Shell")
>>"%PWSH_LAUNCHER%" echo cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ""$self=$env:SERVE_HTML_SELF; try { $lines=Get-Content -LiteralPath $self; $marker='#__PWSH_PAYLOAD_START__'; $markerLine=-1; for($i=0;$i -lt $lines.Length;$i++){ if($lines[$i] -eq $marker){ $markerLine=$i; break } }; if($markerLine -lt 0){ throw 'Marcador do payload nao encontrado.' }; if(($markerLine + 1) -ge $lines.Length){ throw 'Payload PowerShell vazio.' }; $code=($lines[($markerLine+1)..($lines.Length-1)] -join [Environment]::NewLine); [ScriptBlock]::Create($code).Invoke() } catch { Add-Content -LiteralPath $env:SERVE_HTML_LOG -Value ('['+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')+'] LOADER ERROR: '+$_.Exception.ToString()); exit 1 }"""
>>"%PWSH_LAUNCHER%" echo oShell.Run cmd, 0, False

wscript.exe "%PWSH_LAUNCHER%"
exit /b 0

goto :eof

#__PWSH_PAYLOAD_START__
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message)
    Add-Content -LiteralPath $env:SERVE_HTML_LOG -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

function Get-ContentType {
    param([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.html'  { 'text/html; charset=utf-8' }
        '.htm'   { 'text/html; charset=utf-8' }
        '.css'   { 'text/css; charset=utf-8' }
        '.js'    { 'application/javascript; charset=utf-8' }
        '.mjs'   { 'application/javascript; charset=utf-8' }
        '.json'  { 'application/json; charset=utf-8' }
        '.svg'   { 'image/svg+xml' }
        '.png'   { 'image/png' }
        '.jpg'   { 'image/jpeg' }
        '.jpeg'  { 'image/jpeg' }
        '.gif'   { 'image/gif' }
        '.webp'  { 'image/webp' }
        '.ico'   { 'image/x-icon' }
        '.txt'   { 'text/plain; charset=utf-8' }
        '.md'    { 'text/markdown; charset=utf-8' }
        '.map'   { 'application/json; charset=utf-8' }
        '.xml'   { 'application/xml; charset=utf-8' }
        '.woff'  { 'font/woff' }
        '.woff2' { 'font/woff2' }
        '.ttf'   { 'font/ttf' }
        '.otf'   { 'font/otf' }
        '.eot'   { 'application/vnd.ms-fontobject' }
        '.wasm'  { 'application/wasm' }
        default  { 'application/octet-stream' }
    }
}

function Send-Response {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$StatusText,
        [byte[]]$Body,
        [string]$ContentType
    )

    if ($null -eq $Body) {
        $Body = [byte[]]::new(0)
    }
    if ([string]::IsNullOrWhiteSpace($ContentType)) {
        $ContentType = 'application/octet-stream'
    }

    $headerText = "HTTP/1.1 {0} {1}`r`nContent-Type: {2}`r`nContent-Length: {3}`r`nConnection: close`r`n`r`n" -f $StatusCode, $StatusText, $ContentType, $Body.Length
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerText)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($Body.Length -gt 0) {
        $Stream.Write($Body, 0, $Body.Length)
    }
    $Stream.Flush()
}

$listener = $null
try {
    $root = [System.IO.Path]::GetFullPath($env:SERVE_HTML_DIR)
    if (-not $root.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $root += [System.IO.Path]::DirectorySeparatorChar
    }

    $index = [System.IO.Path]::GetFileName($env:SERVE_HTML_NAME)
    $port  = [int]$env:SERVE_HTML_PORT

    Write-Log ("START root='{0}' index='{1}' port={2}" -f $root, $index, $port)

    $ip = [System.Net.IPAddress]::Parse('127.0.0.1')
    $listener = [System.Net.Sockets.TcpListener]::new($ip, $port)
    $listener.Server.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
    $listener.Start()

    Write-Log 'TcpListener iniciado com sucesso.'

    $targetUrl = "http://127.0.0.1:{0}/{1}" -f $port, [Uri]::EscapeDataString($index)
    Write-Log ("Abrindo navegador em: {0}" -f $targetUrl)
    Start-Process $targetUrl

    $deadline = (Get-Date).ToUniversalTime().AddMinutes(10)

    while ((Get-Date).ToUniversalTime() -lt $deadline) {
        if (-not $listener.Pending()) {
            Start-Sleep -Milliseconds 200
            continue
        }

        $client = $listener.AcceptTcpClient()
        $deadline = (Get-Date).ToUniversalTime().AddMinutes(10)

        try {
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 8192, $true)

            $requestLine = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($requestLine)) {
                Write-Log 'REQUEST ERROR: linha inicial vazia.'
                Send-Response -Stream $stream -StatusCode 400 -StatusText 'Bad Request' -Body ([System.Text.Encoding]::UTF8.GetBytes('400')) -ContentType 'text/plain; charset=utf-8'
                continue
            }

            while ($true) {
                $headerLine = $reader.ReadLine()
                if ($null -eq $headerLine -or $headerLine -eq '') { break }
            }

            $parts = $requestLine.Split(' ')
            if ($parts.Length -lt 2) {
                Write-Log ("REQUEST ERROR: request line invalida: {0}" -f $requestLine)
                Send-Response -Stream $stream -StatusCode 400 -StatusText 'Bad Request' -Body ([System.Text.Encoding]::UTF8.GetBytes('400')) -ContentType 'text/plain; charset=utf-8'
                continue
            }

            $method = $parts[0].ToUpperInvariant()
            $rawTarget = $parts[1]

            if ($method -ne 'GET' -and $method -ne 'HEAD') {
                Write-Log ("405: metodo nao suportado: {0}" -f $method)
                Send-Response -Stream $stream -StatusCode 405 -StatusText 'Method Not Allowed' -Body ([System.Text.Encoding]::UTF8.GetBytes('405')) -ContentType 'text/plain; charset=utf-8'
                continue
            }

            $pathOnly = $rawTarget.Split('?')[0]
            $decoded = [Uri]::UnescapeDataString($pathOnly)
            $decoded = $decoded.TrimStart('/') -replace '/', '\\'
            if ([string]::IsNullOrWhiteSpace($decoded)) {
                $decoded = $index
            }

            $full = [System.IO.Path]::GetFullPath((Join-Path $root $decoded))
            if ((-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) -or (-not [System.IO.File]::Exists($full))) {
                Write-Log ("404: {0}" -f $full)
                Send-Response -Stream $stream -StatusCode 404 -StatusText 'Not Found' -Body ([System.Text.Encoding]::UTF8.GetBytes('404')) -ContentType 'text/plain; charset=utf-8'
                continue
            }

            $bytes = [System.IO.File]::ReadAllBytes($full)
            $contentType = Get-ContentType -Path $full
            Write-Log ("200: {0}" -f $full)

            if ($method -eq 'HEAD') {
                Send-Response -Stream $stream -StatusCode 200 -StatusText 'OK' -Body ([byte[]]::new(0)) -ContentType $contentType
            } else {
                Send-Response -Stream $stream -StatusCode 200 -StatusText 'OK' -Body $bytes -ContentType $contentType
            }
        }
        catch {
            Write-Log ("REQUEST ERROR: {0}" -f $_.Exception.ToString())
            try {
                if ($stream) {
                    Send-Response -Stream $stream -StatusCode 500 -StatusText 'Internal Server Error' -Body ([System.Text.Encoding]::UTF8.GetBytes('500')) -ContentType 'text/plain; charset=utf-8'
                }
            } catch {}
        }
        finally {
            try { if ($reader) { $reader.Dispose() } } catch {}
            try { if ($stream) { $stream.Dispose() } } catch {}
            try { $client.Close() } catch {}
        }
    }

    Write-Log 'Servidor finalizado por timeout/inatividade.'
}
catch {
    Write-Log ("FATAL: {0}" -f $_.Exception.ToString())
}
finally {
    if ($listener) {
        try { $listener.Stop() } catch {}
    }
}
