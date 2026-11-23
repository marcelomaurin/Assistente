@echo off
rem Junta as partes do instalador 0.218 e confere o SHA-256.
cd /d "%~dp0"
copy /Y /B partes_0218\setup_assistente_0218.exe.parte00 + partes_0218\setup_assistente_0218.exe.parte01 + partes_0218\setup_assistente_0218.exe.parte02 + partes_0218\setup_assistente_0218.exe.parte03 + partes_0218\setup_assistente_0218.exe.parte04 + partes_0218\setup_assistente_0218.exe.parte05 + partes_0218\setup_assistente_0218.exe.parte06 + partes_0218\setup_assistente_0218.exe.parte07 + partes_0218\setup_assistente_0218.exe.parte08 + partes_0218\setup_assistente_0218.exe.parte09 + partes_0218\setup_assistente_0218.exe.parte10 + partes_0218\setup_assistente_0218.exe.parte11 + partes_0218\setup_assistente_0218.exe.parte12 + partes_0218\setup_assistente_0218.exe.parte13 + partes_0218\setup_assistente_0218.exe.parte14 + partes_0218\setup_assistente_0218.exe.parte15 + partes_0218\setup_assistente_0218.exe.parte16 + partes_0218\setup_assistente_0218.exe.parte17 setup_assistente_0218.exe >nul
certutil -hashfile setup_assistente_0218.exe SHA256 | findstr /i "ea1c354a3ed097fc8dc254292b184ce2ca54a0831403e8b8becc98f086aba697" >nul
if errorlevel 1 (echo ERRO: SHA-256 nao confere. & exit /b 1)
echo OK: setup_assistente_0218.exe montado e conferido.
