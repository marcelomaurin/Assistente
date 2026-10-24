@echo off
rem Junta as partes do instalador 0.216 e confere o SHA-256.
cd /d "%~dp0"
copy /Y /B partes_0216\setup_assistente_0216.exe.parte00 + partes_0216\setup_assistente_0216.exe.parte01 + partes_0216\setup_assistente_0216.exe.parte02 + partes_0216\setup_assistente_0216.exe.parte03 + partes_0216\setup_assistente_0216.exe.parte04 + partes_0216\setup_assistente_0216.exe.parte05 + partes_0216\setup_assistente_0216.exe.parte06 + partes_0216\setup_assistente_0216.exe.parte07 + partes_0216\setup_assistente_0216.exe.parte08 + partes_0216\setup_assistente_0216.exe.parte09 + partes_0216\setup_assistente_0216.exe.parte10 + partes_0216\setup_assistente_0216.exe.parte11 + partes_0216\setup_assistente_0216.exe.parte12 + partes_0216\setup_assistente_0216.exe.parte13 + partes_0216\setup_assistente_0216.exe.parte14 + partes_0216\setup_assistente_0216.exe.parte15 + partes_0216\setup_assistente_0216.exe.parte16 setup_assistente_0216.exe >nul
certutil -hashfile setup_assistente_0216.exe SHA256 | findstr /i "fa7aaca1d5f80b6d3fbefe16c0a3a8424e507501c5c9d7ef412278cb32b06f7f" >nul
if errorlevel 1 (echo ERRO: SHA-256 nao confere. & exit /b 1)
echo OK: setup_assistente_0216.exe montado e conferido.
