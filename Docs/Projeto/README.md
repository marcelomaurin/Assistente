# Projeto e funcionalidades

[Índice](../README.md) · [Manual do usuário](../ManualUsuario/README.md) · [DLL](../DLL/README.md) · [Socket](../Socket/README.md)

## Objetivo e funcionamento

O Assistente foi criado para responder perguntas no contexto da FATEC. A aplicação desktop reúne chat, componentes CHATGPT, planejamento por agentes, memória de conversa, voz e apresentação por avatar 3D nativo. Pode usar provedores configurados e serviços externos; a presença da interface não significa que credenciais, equipamentos ou servidores estejam disponíveis.

O fluxo principal é: texto ou transcrição → `TAssistantManager` → provedor/planejamento → resposta → histórico/chat → apresentação com gestos e, se habilitada, síntese de voz. A integração externa envia pedidos ao mesmo fluxo. A DLL é um cliente TCP; o aplicativo continua responsável pela IA e pelo avatar.

## Funcionalidades

| Área | Comportamento atual | Dependências ou limites |
| --- | --- | --- |
| Conversa | Entrada por texto, respostas no chat e histórico local | Provedor/modelo/credencial e conectividade corretos |
| Agente | Planejamento em etapas, subtarefas e ferramentas existentes | A disponibilidade efetiva depende do serviço e do plano; não é garantia de execução autônoma de qualquer tarefa |
| Memória | Registro de interações em `conversation-history.json` | Arquivo local, sem promessa de armazenamento remoto |
| Avatar | Dez perfis, seleção, atualização do catálogo, zoom e reenquadramento | GPU/driver OpenGL compatível; arquivos `AVATARES` correspondentes |
| Anatomia v4 | Corpo inteiro sob roupas, ombro/clavícula, mandíbula/lábios, olhos/pálpebras e dedos animados por esqueleto | Aproximação visual; sem simulação muscular e sem alinhamento por fonemas |
| Apresentação | Repouso, escuta, pensamento, fala, aceno, caminhada e tags de gesto | Modelos personalizados precisam de clipes compatíveis |
| Saída de voz | Síntese configurável, apresentação acompanhando reprodução de áudio | SAPI/serviço de voz e dispositivo de saída disponíveis |
| Entrada de voz | Captura/transcrição e escuta contínua configurável | Microfone, mecanismo de reconhecimento e permissões do Windows |
| Vídeo | Câmera RGB local e/ou Kinect v1, com seleção e teste | VFW para câmera; SDK/hardware Kinect para profundidade/esqueleto |
| Jarvis | Configuração e ferramentas de consulta/acionamento de ambiente | Servidor e credencial próprios; não confundir com token da integração |
| Bancos | Campos de conexão MySQL/PostgreSQL preservados | Configurar esses campos não cria banco nem comprova integração completa do chat com ele |
| Integração externa | API JSON v1 para consulta, conversa assíncrona, fala, gestos, seleção e cancelamento | Desativada por padrão; IPv4, token e IP permitido; aplicativo aberto |

Veja a [descrição técnica dos avatares](../professor-virtual-3d.md) e o [vocabulário de tags](../avatar-comandos-ia.md).

## Mapa das fontes

| Pasta/arquivo | Responsabilidade |
| --- | --- |
| `src/assistente.lpr`, `src/main.pas` | Inicialização, janela, chat e encaminhamento das ações |
| `src/agent_manager.pas` | Agente, planejamento, ferramentas e trabalho assíncrono |
| `src/setmain.pas`, `src/frmconfig.pas`, `src/professor_settings.pas` | Persistência e interface de configuração |
| `src/professor_view.pas`, `src/professor_state.pas`, `src/professor_commands.pas` | Renderer, estados e comandos do avatar |
| `src/professor_catalog.pas`, `AVATARES/` | Descoberta, metadados, modelos e licenças |
| `src/reception_core.pas`, `src/voice_input_bridge.pas`, `src/professor_listener.pas` | Síntese, entrada e ciclo de voz |
| `src/webcam_vision.pas`, `src/vision_types.pas` | Vídeo e seleção de fontes locais |
| `src/assistant_integration_protocol.pas` | Configuração, token, IPs, validação JSON/UTF-8 e envelopes |
| `src/assistant_integration_net.pas` | Transporte Windows TCP com prazos e limites |
| `src/assistant_integration_server.pas` | Listener e fila de entrega ao formulário |
| `src/assistant_integration_jobs.pas` | Resultados assíncronos, limitados e em memória |
| `src/assistant_integration_settings_ui.pas` | Aba Integração externa |
| `src/assistant_integration_client.pas`, `sdk/` | Cliente Pascal, DLL C ABI, cabeçalho e exemplo Python |
| `vendor/chatgpt-voice/` | Adaptadores de voz fixados, com origem/licenças documentadas |
| `scripts/`, `tests/`, `tools/` | Compilação, verificações e autoria dos modelos |
| `bin/` | Instalador histórico e DLLs publicadas; confira os manifestos |

O servidor atende uma conexão por vez em thread própria. Pedidos autenticados entram em fila limitada e são executados pelo timer na thread da interface; a thread de rede não modifica controles nem renderer. Perguntas iniciam o agente e retornam um ID imediatamente. O cliente acompanha esse ID por `get_job`.

## Configuração e dados

`Setmain.cfg` é lido/gravado na pasta retornada por `GetAppConfigDir(False)`. A variável `ASSISTENTE_CONFIG_DIR` substitui esse diretório, permitindo perfis de teste separados. Com essa variável, o histórico também fica nesse diretório; sem ela, o histórico mantém o caminho legado ao lado do executável.

O token da integração é gerado com 32 bytes aleatórios pelo Windows e salvo protegido por DPAPI. Não copie um token protegido entre usuários/máquinas como se fosse uma credencial portável. A configuração também contém dados de outros serviços, que conservam suas próprias regras de armazenamento; não publique o arquivo completo. A resposta de `status` não divulga esses dados.

## Compilação

Ambiente verificado: Windows, Free Pascal 3.2.2 Win32 para o aplicativo, Lazarus/LCL, Castle Game Engine na revisão `6a433378a8cc7117f5deccbec2fb70a42fdb98f3`. As DLLs usam FPC 3.2.2 Win32 e Win64. Python 3 é necessário para os testes; numpy/Pillow são usados apenas na autoria dos avatares.

Na raiz do repositório:

```powershell
.\scripts\build_professor.ps1 -Castle 'C:\caminho\castle-engine' -Release
.\scripts\build_integration.ps1
```

O primeiro comando produz `build/professor/assistente.exe` e copia `AVATARES` para junto dele. Não atualiza automaticamente executáveis antigos de `src` nem uma instalação já existente. As bibliotecas SSL Win32 necessárias ao provedor HTTPS devem acompanhar o aplicativo, conforme o [guia de instalação](../INSTALACAO_0120.md).

Por padrão, `build_professor.ps1` prepara uma cópia isolada da biblioteca CHATGPT em `.deps/chatgpt-integration-baseline`, usando a revisão conhecida `3c845b998c7c631c0608c12b766a04b39da13be1`. O checkout local de origem precisa conter esse commit; o padrão é `..\CHATGPT`. Para outra localização:

```powershell
.\scripts\prepare_chatgpt_baseline.ps1 -Source 'C:\caminho\CHATGPT'
```

Uma dependência diferente pode ser informada com `-ChatGPT`; sua compatibilidade deve ser verificada. A cópia isolada evita alterar o trabalho em andamento na biblioteca compartilhada. Use `-Rebuild` após trocar uma dependência. Leia os parâmetros de `build_professor.ps1` para caminhos de Lazarus/FPC alternativos.

## Verificações

Compile primeiro as ferramentas de teste na raiz:

```powershell
New-Item -ItemType Directory -Force build/integration/win32,build/integration/win64 | Out-Null
& 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe' -MObjFPC -O1 -Fusrc -FUbuild/integration/win32 -FEbuild/integration tests/integration_server_fixture.lpr
& 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe' -MObjFPC -O1 -Fusrc -FUbuild/integration/win32 -FEbuild/integration/win32 tests/integration_dll_probe.lpr
& 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe' -MObjFPC -O1 -Fusrc -FUbuild/integration/win64 -FEbuild/integration/win64 tests/integration_dll_probe.lpr
python tests/run_integration_checks.py
python tests/run_integration_host_checks.py
python tests/check_docs.py
```

O primeiro teste usa TCP real, credenciais fictícias e executáveis de prova nas duas arquiteturas. Verifica token, lista de IPs, mensagens inválidas, Unicode, limites e ABI. O segundo abre a aplicação Release real com configuração isolada e provedor HTTP local simulado, verifica conversa assíncrona/cancelamento, avatar e persistência protegida. Ambos geram resultados em `build/integration`; não usam chaves pagas nem equipamentos de voz/vídeo.

A verificação da documentação confere existência dos arquivos, caixa dos nomes para navegação no GitHub e âncoras de seções. Para testar a própria aba de configuração:

```powershell
.\scripts\build_professor.ps1 -Castle 'C:\caminho\castle-engine' -Release -Target tests/integration_settings_check.lpr
.\build\professor\integration_settings_check.exe
```

Esse teste verifica padrões, botão de geração aleatória, mascaramento do token, validação da lista, transferência dos ajustes e largura da aba nativa. A captura usa dados de demonstração e não divulga credenciais reais.

Os testes de avatar, comandos, voz e vídeo anteriores estão descritos nos guias específicos e em `tests/`. Uma aprovação com provedor simulado não comprova uma conta real, microfone, Kinect, acesso remoto ou todos os modelos de GPU. O [guia socket](../Socket/README.md) registra os limites da integração.

## Versões

| Identificação | Significado |
| --- | --- |
| Instalador 0.120 | Distribuição anterior às novas interfaces de integração |
| Avatares v4 | Revisão artística com animação facial/ocular/dedos por esqueleto |
| Protocolo v1 | Campo JSON `v:1` e ações descritas no guia socket |
| ABI 1.0 | `AssistenteApiVersion() = 0x00010000` |

Os arquivos em `bin/integration` são clientes das fontes atuais. Leia o manifesto de hashes ao distribuí-los. Qualquer pacote posterior deve incluir um executável do Assistente com essa API, seus avatares e dependências; a DLL sozinha não implementa o professor virtual.
