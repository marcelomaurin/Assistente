@echo off
rem Junta as partes do instalador 0.215 e confere o SHA-256.
cd /d "%~dp0"
copy /Y /B partes_0215\setup_assistente_0215.exe.parte00 + partes_0215\setup_assistente_0215.exe.parte01 + partes_0215\setup_assistente_0215.exe.parte02 + partes_0215\setup_assistente_0215.exe.parte03 + partes_0215\setup_assistente_0215.exe.parte04 + partes_0215\setup_assistente_0215.exe.parte05 + partes_0215\setup_assistente_0215.exe.parte06 + partes_0215\setup_assistente_0215.exe.parte07 + partes_0215\setup_assistente_0215.exe.parte08 + partes_0215\setup_assistente_0215.exe.parte09 + partes_0215\setup_assistente_0215.exe.parte10 + partes_0215\setup_assistente_0215.exe.parte11 + partes_0215\setup_assistente_0215.exe.parte12 + partes_0215\setup_assistente_0215.exe.parte13 + partes_0215\setup_assistente_0215.exe.parte14 + partes_0215\setup_assistente_0215.exe.parte15 + partes_0215\setup_assistente_0215.exe.parte16 setup_assistente_0215.exe >nul
certutil -hashfile setup_assistente_0215.exe SHA256 | findstr /i "a2df19e2047ee0aad1a88980ae11cffb8a6a05ae5f9dc79e9915c536b7c65a10" >nul
if errorlevel 1 (echo ERRO: SHA-256 nao confere. & exit /b 1)
echo OK: setup_assistente_0215.exe montado e conferido (SHA-256 a2df19e2047ee0aad1a88980ae11cffb8a6a05ae5f9dc79e9915c536b7c65a10).
