@echo off
setlocal

set "LOG=D:\projetos\maurinsoft\Assistente\build_log.txt"
set "LPI=D:\projetos\maurinsoft\Assistente\src\assistente.lpi"

echo ==== compile_check iniciado em %DATE% %TIME% ==== > "%LOG%"

set "LAZBUILD=C:\lazarus\lazbuild.exe"
if not exist "%LAZBUILD%" set "LAZBUILD=C:\Lazarus\lazbuild.exe"
if not exist "%LAZBUILD%" (
  for /f "delims=" %%F in ('where lazbuild.exe 2^>nul') do set "LAZBUILD=%%F"
)

echo Usando LAZBUILD=%LAZBUILD% >> "%LOG%"

if not exist "%LAZBUILD%" (
  echo ERRO: nao encontrei o lazbuild.exe automaticamente. >> "%LOG%"
  echo Ajuste manualmente o caminho no compile_check.bat. >> "%LOG%"
  goto FIM
)

"%LAZBUILD%" "%LPI%" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ==== ExitCode=%ERRORLEVEL% ==== >> "%LOG%"

:FIM
echo ==== compile_check finalizado ==== >> "%LOG%"
