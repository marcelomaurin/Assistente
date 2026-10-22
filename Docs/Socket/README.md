# Protocolo de comunicação socket — v1

[Índice](../README.md) · [Projeto](../Projeto/README.md) · [DLL](../DLL/README.md) · [Configurar no aplicativo](../ManualUsuario/README.md#integração-com-outros-programas)

## Transporte e autorização

TCP IPv4, JSON UTF-8 delimitado por LF (`0x0A`, JSON Lines). Não é HTTP nem WebSocket. Cada conexão transporta **um pedido e uma resposta**, depois é fechada. Não há streaming de áudio, eventos enviados espontaneamente ou sessão autenticada persistente.

Padrões: desabilitado, endereço `127.0.0.1`, porta `18766`, lista permitida `127.0.0.1` e token vazio. Para ativar, informe um token de 64 caracteres hexadecimais e de 1 a 128 IPv4 individuais permitidos. O botão de geração usa 32 bytes aleatórios do Windows. O token é sensível à caixa, inclusive nas letras hexadecimais.

O endereço de escuta determina em qual interface o servidor recebe conexões. `127.0.0.1` aceita somente acesso local; `0.0.0.0` escuta em todas as interfaces IPv4. A lista permitida é independente: `0.0.0.0` na lista **não** significa liberar todos. Lista aceita IPs literais separados por linha, `;` ou `,`, sem DNS, wildcard ou CIDR. O IP verificado é o par real da conexão, antes da leitura do pedido. Campos `ip`, `forwarded_for` e semelhantes não substituem essa verificação. Em NAT/VPN, autorize o endereço que efetivamente chega ao servidor.

Token e IP são necessários para todas as ações, inclusive `status` e `avatars`. Não há consulta pública de saúde. A DLL usa essas mesmas regras. A autorização concede acesso ao conjunto de ações, sem usuários/papéis/permissões individuais por ação; permita somente ferramentas de confiança. `ask` utiliza o agente e as ferramentas já configuradas no aplicativo.

**Este transporte TCP não implementa TLS.** O token autentica, mas não cifra tráfego, perguntas ou respostas. Use loopback ou rede privada/VPN confiável. Não publique essa porta diretamente na Internet. O HTTPS de um provedor de IA é outra conexão e não protege este TCP.

## Chaves de configuração

A interface grava estas entradas em `Setmain.cfg`. Prefira configurar pela aba do aplicativo; a tabela serve para manutenção e ambientes isolados de teste.

| Chave | Conteúdo |
| --- | --- |
| `INTEGRATION_ENABLED` | `1` habilita, demais valores desabilitam |
| `INTEGRATION_BIND` | IPv4 de escuta |
| `INTEGRATION_PORT` | Inteiro de 1 a 65535 |
| `INTEGRATION_TOKEN` | Token protegido por DPAPI ao salvar; não é o valor protegido que o cliente envia |
| `INTEGRATION_ALLOWED_IPS` | Lista de IPv4 separados por ponto e vírgula |

O cliente envia o token original mostrado na interface. Configuração ativa inválida ou falha de bind impede o início do listener; a aba apresenta o diagnóstico. Ao salvar alterações, o listener anterior é encerrado e recriado. Desabilitar não requer apagar o token, permitindo reativação posterior sob controle do usuário.

## Envelopes

Pedido socket direto, seguido de um LF real:

```json
{"v":1,"token":"TOKEN_CONFIGURADO_64_HEX","action":"status"}
```

A expressão acima é um marcador de documentação, não um token válido. A DLL recebe o token em argumento separado; o JSON da DLL omite `token`.

Sucesso:

```json
{"v":1,"ok":true,"result":{"service":"Assistente","busy":false,"state":"Pronto","profile":"professor","speaking":false}}
```

O texto de `state` é informativo e pode variar; não o trate como enumeração estável. `speaking` indica trabalho de fala existente, incluindo preparação do áudio; não comprova que som esteja saindo neste instante.

Erro:

```json
{"v":1,"ok":false,"error":"unauthorized"}
```

O parser exige um objeto raiz, `v` numérico inteiro exatamente 1, `action` string não vazia e UTF-8 válido. Rejeita campos duplicados no nível superior, bytes NUL, lixo após o JSON e profundidade acima de 32. Campos adicionais não são argumentos de execução arbitrária. Os campos de ações são sensíveis à caixa.

## Ações

Os exemplos abaixo omitem o token para facilitar a leitura. Acrescente-o no socket direto.

| `action` | Campos adicionais | `result` ou efeito |
| --- | --- | --- |
| `status` | Nenhum | `service`, `busy`, `state`, `profile`, `speaking` |
| `avatars` | Nenhum | Lista de objetos `id`, `name` do catálogo; sem caminhos privados |
| `ask` | `text`: string não vazia, até 8.192 bytes UTF-8 após aparar espaços | Inicia conversa pelo agente; retorna `id` |
| `get_job` | `id`: ID recebido de `ask` | Estado e, ao terminar, texto/provedor |
| `speak` | `text`: mesma regra de `ask` | Inicia apresentação de fala; retorna `accepted:true`; exige fala automática habilitada |
| `avatar` | `command`: um dos valores abaixo | Executa gesto; retorna `accepted:true` se suportado |
| `select_avatar` | `id`: ID presente em `avatars` | Troca e salva perfil; retorna `id` |
| `cancel` | Nenhum | Solicita cancelamento de agente/apresentação e limpa comandos; retorna `accepted:true` |

Comandos de `avatar`: `smile`, `neutral`, `applause`, `raise_right_hand`, `lower_right_hand`, `wave`, `walk`. Não são tags em português; essas continuam disponíveis no texto das respostas conforme o [guia de comandos da IA](../avatar-comandos-ia.md).

`status`, `avatars` e `get_job` podem ser consultados durante o processamento. Ações novas que alteram apresentação/conversa retornam `busy` enquanto há IA, fala, transcrição ou configuração modal em andamento. `cancel` pode interromper processamento ativo, mas retorna `busy` durante a configuração/encerramento. Cancelamento é cooperativo: aceitação não significa conclusão imediata. Verifique o estado do trabalho.

`speak` não cria um trabalho consultável por `get_job`. `accepted` confirma que a apresentação foi iniciada/aceita; uma falha posterior do sintetizador ainda pode ocorrer. Gestos aceitos dependem dos clipes e prioridades do avatar carregado.

Não há ação para carregar caminho arbitrário, executar shell, enviar bytes de áudio ou configurar credenciais. A seleção remota é restrita ao catálogo. A conversa reutiliza o agente existente, que tem suas próprias ferramentas; a API não cria uma sandbox adicional para o agente.

## Pergunta assíncrona

```json
{"v":1,"action":"ask","text":"Explique o microscópio"}
```

```json
{"v":1,"ok":true,"result":{"id":"ID_OPACO"}}
```

Em outra conexão autenticada:

```json
{"v":1,"action":"get_job","id":"ID_OPACO"}
```

```json
{"v":1,"ok":true,"result":{"id":"ID_OPACO","state":"running"}}
```

Depois:

```json
{"v":1,"ok":true,"result":{"id":"ID_OPACO","state":"completed","text":"Resposta produzida pelo provedor.","provider":"CHATGPT Suite"}}
```

Estados: `running`, `completed`, `failed`, `cancelled`. Um ID aceito pode terminar em falha. O resultado terminal da conversa não significa que a fala já terminou. São mantidos no máximo 32 trabalhos em memória; novos trabalhos removem os mais antigos. Reiniciar perde os IDs. Texto armazenado no resultado é limitado a 65.536 bytes UTF-8, preservando caracteres completos. O histórico do chat tem persistência própria e não serve como catálogo de IDs da API.

Consulte com intervalo moderado, por exemplo 250–500 ms, e um prazo total escolhido pelo seu programa. Não há garantia de duração do provedor.

## Erros

| `error` | Causa |
| --- | --- |
| `ip_not_allowed` | IP real fora da lista; a conexão pode ser encerrada/resetada antes de o cliente receber JSON |
| `invalid_frame` | Pedido sem LF dentro do prazo, EOF prematuro ou limite excedido |
| `invalid_request` | JSON, versão, campos básicos ou UTF-8 inválidos |
| `unauthorized` | Token ausente/incorreto, para um pedido estruturalmente válido |
| `busy` | Aplicativo ocupado para aquela ação |
| `unknown_action` | Ação não implementada |
| `invalid_text` | Texto ausente, vazio, de tipo errado ou longo demais |
| `invalid_command` | Nome de gesto inválido |
| `unsupported_gesture` | Renderer/modelo não aceitou o gesto |
| `not_found` | Avatar ou trabalho inexistente, removido ou perdido no reinício |
| `speech_disabled` | Fala automática desativada |
| `speech_unavailable` | Não foi possível iniciar apresentação de fala |
| `dispatch_timeout` | Interface não processou o pedido no prazo |
| `response_too_large` | Resposta excedeu o limite |
| `unavailable` | Handler não disponível ou sem resposta |
| `internal_error` | Exceção durante o atendimento na aplicação |

Falhas de conexão ou desconexão podem não produzir JSON. Não repita automaticamente ações com efeitos após timeout: o pedido pode ter sido executado sem que a resposta chegasse. Não existe chave de idempotência/deduplicação nesta versão.

## Limites operacionais

| Item | Limite atual |
| --- | --- |
| Pedido | 16.384 bytes, excluindo LF; inclui token e JSON serializado |
| Resposta | 1.048.576 bytes, excluindo LF |
| Leitura do pedido no servidor | 3 s para o frame inteiro, sem renovação por byte |
| Entrega à interface | 10 s |
| Envio da resposta pelo servidor | 1 s |
| Clientes | Um atendimento por vez, backlog de escuta 8; sem garantia de oito pedidos executados simultaneamente |
| Fila de interface | Um pedido pendente |
| IPs permitidos | De 1 a 128 entradas IPv4 |

Envie o LF mesmo se fragmentar o pacote em vários envios TCP. Escape quebras de linha internas de strings pelo JSON. Não envie vários pedidos na mesma conexão. O prazo limita o impacto de um cliente silencioso; esta implementação não é um servidor de alta concorrência.

## Exemplo executável

Com `ASSISTENTE_TOKEN` configurada no ambiente e integração habilitada:

```powershell
python sdk/examples/assistente_client.py status
python sdk/examples/assistente_client.py ask --text 'Olá, professor'
python sdk/examples/assistente_client.py get_job --id ID_RECEBIDO
python sdk/examples/assistente_client.py avatar --command wave
```

Para outra máquina, use `--host IPV4_DO_ASSISTENTE --port PORTA` e configure endereço de escuta/lista permitida no aplicativo. O [mesmo cliente Python](../../sdk/examples/assistente_client.py) usa a DLL quando recebe `--dll`. Ele não repete ações automaticamente.

## Migração do protótipo anterior

O servidor antigo que aceitava uma linha de transcrição na porta 18765 não é iniciado pelo aplicativo atual. O protótipo Android e qualquer ferramenta antiga devem passar a enviar objeto JSON com token para a porta configurada e tratar `ask`/`get_job`. Não envie texto bruto. Esta mudança não inclui geração ou validação de um APK Android atualizado.
