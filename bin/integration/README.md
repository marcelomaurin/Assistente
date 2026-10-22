# DLLs de integração — ABI 1.0 / protocolo v1

Arquivos cliente para o Assistente atual:

- `win32/assistente_integration.dll`: processos de 32 bits.
- `win64/assistente_integration.dll`: processos de 64 bits.
- [Manifesto de arquivos e hashes](manifest.json).
- [Resultados das verificações](validacao.json).

O aplicativo precisa estar aberto com a integração habilitada, token válido e IP permitido. O instalador histórico `setup_assistente_0120.exe` é anterior a essa API. Compile o host atual conforme o [guia do projeto](../../Docs/Projeto/README.md#compilação).

Consulte o [guia DLL](../../Docs/DLL/README.md), o [protocolo socket](../../Docs/Socket/README.md) e o [manual](../../Docs/ManualUsuario/README.md#integração-com-outros-programas). O SDK e o cliente Python ficam em `sdk/` na raiz do repositório. TCP autenticado não implica criptografia TLS.
