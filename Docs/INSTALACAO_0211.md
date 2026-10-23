# Assistente 0.211 — YouTube na apresentação

O instalador `bin/setup_assistente_0211.exe` atualiza o Assistente e o Editor.
Inclui a tag `[youtube=link]`, o botão **YouTube** no editor e reprodução
incorporada por clique, com espera pelo término, pausa e cancelamento.

As configurações, o histórico e os movimentos personalizados são preservados.
O vídeo é transmitido pelo YouTube: é necessário internet e o Microsoft Edge
WebView2 Runtime, já presente na máquina usada na validação. O carregador
WebView2 e sua licença acompanham o pacote.

Veja [YouTube nas apresentações](youtube-apresentacoes.md) para inserir vídeos.

## Gerar e validar

```powershell
python scripts/build_presentations.py --release --compiler C:/lazarus/fpc/3.2.2/bin/i386-win32/fpc.exe --out build/presentations-0211
./scripts/build_installer.ps1 -Version 0.211 -BuildCode 0211
python tests/check_installer.py --build-code 0211 --version 0.211 --no-ui
```
