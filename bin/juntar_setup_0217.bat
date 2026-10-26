@echo off
rem Junta as partes do instalador 0.217 e confere o SHA-256.
cd /d "%~dp0"
copy /Y /B partes_0217\setup_assistente_0217.exe.parte00 + partes_0217\setup_assistente_0217.exe.parte01 + partes_0217\setup_assistente_0217.exe.parte02 + partes_0217\setup_assistente_0217.exe.parte03 + partes_0217\setup_assistente_0217.exe.parte04 + partes_0217\setup_assistente_0217.exe.parte05 + partes_0217\setup_assistente_0217.exe.parte06 + partes_0217\setup_assistente_0217.exe.parte07 + partes_0217\setup_assistente_0217.exe.parte08 + partes_0217\setup_assistente_0217.exe.parte09 + partes_0217\setup_assistente_0217.exe.parte10 + partes_0217\setup_assistente_0217.exe.parte11 + partes_0217\setup_assistente_0217.exe.parte12 + partes_0217\setup_assistente_0217.exe.parte13 + partes_0217\setup_assistente_0217.exe.parte14 + partes_0217\setup_assistente_0217.exe.parte15 + partes_0217\setup_assistente_0217.exe.parte16 + partes_0217\setup_assistente_0217.exe.parte17 setup_assistente_0217.exe >nul
certutil -hashfile setup_assistente_0217.exe SHA256 | findstr /i "a31bebbc1aad6874d857e940a3655c0c63e82aa767174b1de73c0f8009a7b65c" >nul
if errorlevel 1 (echo ERRO: SHA-256 nao confere. & exit /b 1)
echo OK: setup_assistente_0217.exe montado e conferido.
