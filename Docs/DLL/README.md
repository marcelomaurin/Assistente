# Integração por DLL

[Índice](../README.md) · [Projeto](../Projeto/README.md) · [Protocolo socket](../Socket/README.md) · [Manual](../ManualUsuario/README.md#integração-com-outros-programas)

## O que a DLL faz

`assistente_integration.dll` oferece uma interface C para programas externos enviarem comandos ao Assistente aberto. Usa o mesmo TCP autenticado descrito no guia socket. Não inicia uma segunda IA, não carrega o avatar dentro da ferramenta chamadora e não dispensa token/lista de IPs.

Antes de chamar, execute o aplicativo compilado com a API atual e habilite **Configurações → Integração externa**. O instalador anterior 0.120 ainda não possui esse servidor.

| Arquivo | Processo chamador |
| --- | --- |
| `bin/integration/win32/assistente_integration.dll` | Processo de 32 bits |
| `bin/integration/win64/assistente_integration.dll` | Processo de 64 bits |
| [`sdk/assistente_integration.h`](../../sdk/assistente_integration.h) | Contrato C/C++ |
| [`sdk/assistente_integration.lpr`](../../sdk/assistente_integration.lpr) | Fonte da DLL |
| [`sdk/examples/assistente_client.py`](../../sdk/examples/assistente_client.py) | Exemplo executável Python para DLL e socket |

A arquitetura precisa coincidir com o programa que carrega a DLL, mesmo se o Assistente for Win32. Ambas as versões podem conversar com o mesmo servidor. Windows fornece WinSock e BCrypt; a DLL não depende do Lazarus instalado no computador cliente. Carregue a DLL por caminho absoluto e confira o manifesto de hashes de `bin/integration`.

## Funções exportadas e convenção

As duas funções usam **cdecl**, nomes sem decoração e tipos de largura fixa. Strings são UTF-8 terminadas em NUL. Não há objetos Pascal nem memória alocada pela DLL para o chamador liberar.

```c
uint32_t __cdecl AssistenteApiVersion(void);
int32_t __cdecl AssistenteRequestV1(
    const char *host, uint16_t port, const char *token,
    const char *request, char *output, uint32_t capacity,
    uint32_t *required);
```

`AssistenteApiVersion` retorna `0x00010000` (major 1, minor 0). `AssistenteRequestV1` é uma chamada bloqueante. Em interfaces gráficas, execute-a em um trabalho próprio para não bloquear a janela chamadora.

| Argumento | Regras |
| --- | --- |
| `host` | IPv4 literal, como `127.0.0.1`; não usar nome DNS ou IPv6 |
| `port` | Porta configurada, padrão 18766 |
| `token` | Exatamente os 64 caracteres hexadecimais configurados; comparação sensível a maiúsculas/minúsculas |
| `request` | Objeto JSON com `v:1`, `action` e parâmetros; **sem campo `token`** e sem terminador LF obrigatório |
| `output` | Memória gravável do chamador, válida durante toda a chamada |
| `capacity` | Aloque **1.048.577 bytes** antecipadamente; inclui espaço para NUL |
| `required` | Ponteiro gravável para `uint32_t`; recebe o mínimo exigido ou tamanho da resposta com NUL, conforme o retorno |

A DLL acrescenta o token ao envelope e abre uma conexão por chamada. Mensagens maiores que o limite do protocolo são rejeitadas. Não coloque um token dentro do JSON passado à DLL: esse formato é reservado ao socket direto.

## Retornos

| Código | Significado | Conduta |
| --- | --- | --- |
| `0` | Resposta JSON disponível | Leia também `ok`; pode ser `false` por erro de aplicação/autorização |
| `1` | Buffer insuficiente | Não houve envio. Use o buffer mínimo documentado antes de qualquer pedido |
| `2` | Argumentos/pointers ausentes ou fora dos limites de leitura aceitos | Corrija a chamada; não há proteção contra ponteiros arbitrários inválidos fornecidos pelo chamador |
| `3` | Falha de validação do pedido/token/host, transporte ou protocolo de resposta | Investigue a configuração e o servidor; em falha de transporte após envio, o resultado da ação pode ser desconhecido |

Uma resposta `{"v":1,"ok":false,"error":"busy"}` pode chegar com retorno C igual a zero. Isso significa que o transporte funcionou e a aplicação recusou a ação.

Não use chamadas de consulta de tamanho com buffer pequeno seguidas de reenvio indiscriminado. O contrato exige buffer completo desde o início e rejeita o pequeno antes do envio. Não repita automaticamente `ask`, `speak`, `avatar`, `select_avatar` ou `cancel` após timeout: o comando pode já ter sido executado. O protocolo não oferece deduplicação por ID do cliente.

Os prazos do cliente são de até 3 s para conectar, 3 s para enviar e 15 s para ler. Não trate a soma como garantia de tempo exato de parede do sistema operacional. Uma pergunta retorna o ID do trabalho; acompanhar sua conclusão exige novas chamadas `get_job`.

## Exemplo Python

Use Python da mesma arquitetura da DLL. Configure `ASSISTENTE_TOKEN` com o token mostrado no aplicativo, sem gravá-lo no repositório. Na raiz:

```powershell
python sdk/examples/assistente_client.py status --dll bin/integration/win64/assistente_integration.dll
python sdk/examples/assistente_client.py avatars --dll bin/integration/win64/assistente_integration.dll
python sdk/examples/assistente_client.py ask --text 'Explique o microscópio' --dll bin/integration/win64/assistente_integration.dll
python sdk/examples/assistente_client.py get_job --id ID_RECEBIDO --dll bin/integration/win64/assistente_integration.dll
```

Uso como módulo:

```python
import os
from assistente_client import AssistenteClient

client = AssistenteClient(os.environ['ASSISTENTE_TOKEN'],
    dll=r'C:\minha-ferramenta\assistente_integration.dll')
response = client.request('ask', text='Olá, professor')
if response['ok']:
    job_id = response['result']['id']
    # Consultar get_job posteriormente, sem bloquear a interface.
    print(client.request('get_job', id=job_id))
```

Para C/C++, carregue a DLL com `LoadLibraryW` usando caminho absoluto e obtenha as funções com `GetProcAddress`. O cabeçalho descreve o contrato de importação; este SDK não fornece biblioteca `.lib` para todos os compiladores. Em Delphi/Lazarus, declare funções `cdecl` com `LongWord`, `LongInt`, `Word` e `PAnsiChar` UTF-8 e carregue dinamicamente. O [programa de prova Pascal](../../tests/integration_dll_probe.lpr) mostra a chamada real nas duas arquiteturas.

## Compilar e validar

```powershell
.\scripts\build_integration.ps1
```

É possível substituir os caminhos por `-Compiler32` e `-Compiler64`. A DLL usa WinSock2, FPJSON e BCrypt. A suíte e os comandos de compilação dos programas de prova estão no [guia do projeto](../Projeto/README.md#verificações).

Os testes verificam carregamento real das duas DLLs, convenção de chamada, nomes exportados, buffer insuficiente sem envio, Unicode e interoperabilidade Python 64 bits. O teste do aplicativo verifica o processamento por agente com provedor local simulado; não comprova provedores comerciais nem conectividade entre máquinas.

Para ações, erros JSON e autenticação, continue no [protocolo socket](../Socket/README.md). Não existe uma API de ações diferente exclusiva da DLL.
