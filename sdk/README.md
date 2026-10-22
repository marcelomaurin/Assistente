# SDK de integração do Assistente

Leia o [guia da DLL](../Docs/DLL/README.md), o [protocolo socket](../Docs/Socket/README.md) e a [configuração no manual](../Docs/ManualUsuario/README.md#integração-com-outros-programas).

- `assistente_integration.lpr`: fonte Free Pascal da DLL C ABI 1.0.
- `assistente_integration.h`: contrato C/C++.
- `examples/assistente_client.py`: cliente Python 3, via TCP direto ou DLL usando ctypes.

DLLs compiladas: `../bin/integration/win32` e `win64`. Use a arquitetura do processo cliente. O aplicativo precisa estar aberto, com integração habilitada, token válido e IP do cliente permitido. O instalador histórico 0.120 não contém essa API.

Compile com `scripts/build_integration.ps1`. Execute as verificações descritas no [guia do projeto](../Docs/Projeto/README.md#verificações). Os clientes não fazem repetição automática de comandos após falha de transporte.
