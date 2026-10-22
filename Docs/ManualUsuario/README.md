# Manual do usuário do Assistente

[Índice da documentação](../README.md) · [Funcionalidades](../Projeto/README.md) · [DLL](../DLL/README.md) · [Socket](../Socket/README.md)

## 1. Conheça o Assistente

O Assistente conversa por texto e, quando configurado, por voz. Um personagem 3D acompanha a conversa com estados de escuta, pensamento e fala. Você pode escolher a aparência, enviar perguntas, ouvir respostas e conectar ferramentas externas autorizadas.

O programa precisa de um provedor de IA para produzir respostas. Alguns recursos também dependem de serviço de voz, conexão de rede, microfone, câmera ou Kinect. O avatar funcionar na tela não significa que esses serviços estejam configurados.

## 2. Instalação e versão correta

Para o pacote publicado anteriormente, use `bin/setup_assistente_0120.exe`. A instalação padrão fica em `%LOCALAPPDATA%\Programs\Assistente`. O [guia da versão 0.120](../INSTALACAO_0120.md) informa o conteúdo, os hashes e os testes daquele instalador.

**A integração DLL/socket deste manual pertence às fontes atuais e não está no instalador 0.120.** Até existir um instalador posterior contendo essa API, compile conforme o [guia do projeto](../Projeto/README.md#compilação) e abra `build/professor/assistente.exe`, com a pasta `AVATARES` ao lado. Copiar a DLL para um programa antigo não adiciona a aba Integração externa.

Feche a versão anterior antes de abrir a nova. Não execute por engano um `assistente.exe` antigo de outra pasta. Preserve `AVATARES`, texturas e dependências distribuídas junto ao executável. A renderização exige driver gráfico/OpenGL funcional; a comunicação HTTPS usa as bibliotecas SSL da arquitetura do aplicativo.

## 3. Primeiro uso

1. Abra o Assistente e aguarde carregar o personagem.
2. Clique no botão de configurações.
3. Na aba **IA / ChatGPT**, selecione provedor e modelo e informe a credencial daquele serviço. Para um endpoint próprio compatível, informe a URL correspondente.
4. Use **Testar Provedor** para conferir a comunicação. Esse teste pode chamar o serviço configurado.
5. Se desejar ouvir respostas, configure **Output Voice**, teste a voz e marque **Falar respostas recebidas automaticamente**.
6. Se desejar falar com o programa, configure **Entrada de Voz / Microfone** e teste a captação.
7. Clique em **Salvar**. **Cancelar** descarta os ajustes não salvos.
8. Digite uma pergunta curta e envie.

Credenciais de IA, Jarvis, transcrição e integração externa têm finalidades diferentes. Não reutilize o token da integração como chave de um provedor. Não compartilhe seu arquivo completo de configuração.

## 4. Entenda a tela

| Elemento | Uso |
| --- | --- |
| Personagem à esquerda | Apresenta estados e gestos da conversa |
| Seletor de perfil | Troca a aparência do assistente |
| Atualizar `↻` | Relê os modelos da pasta `AVATARES` |
| Botões de aceno/caminhada | Demonstram gestos quando o estado atual permite |
| Microfone | Controla a escuta; confira também a configuração de entrada |
| Conversa à direita | Exibe suas mensagens e respostas |
| Campo inferior e enviar | Recebe a pergunta por texto |
| Indicadores/rodapé | Mostram atividade e disponibilidade dos recursos |

Use a roda do mouse sobre o avatar para aproximar/afastar. Dê duplo clique para reenquadrar. Trocar o personagem também restaura o enquadramento. O zoom altera a visualização, não o arquivo do modelo.

## 5. Conversar por texto

Digite no campo inferior e clique em enviar ou pressione Enter. Aguarde a resposta; o personagem pode entrar em pensamento enquanto o agente trabalha. O processamento pode envolver mais de uma chamada ao provedor, conforme o planejamento.

Evite enviar várias perguntas simultâneas. Se estiver ocupado com IA, transcrição ou fala, termine/cancele a apresentação antes de iniciar outra ação. A conclusão do texto e o final da reprodução da voz podem ocorrer em momentos diferentes.

O chat mantém memória local. A configuração usa o diretório de dados do aplicativo; o histórico legado é salvo junto ao executável. Quando iniciado com `ASSISTENTE_CONFIG_DIR`, configuração e histórico são isolados nesse diretório. Faça backup antes de trocar de computador ou remover dados. A reinstalação do pacote 0.120 foi verificada preservando configuração/histórico; isso não substitui um backup próprio.

## 6. Ouvir as respostas

Em **Output Voice**, escolha o mecanismo de síntese, voz e, quando aplicável, modelo. Ajuste volume e velocidade e use o teste de voz. Marque fala automática para que respostas também sejam narradas.

Serviços remotos precisam de endpoint/credencial válidos; vozes locais dependem das vozes instaladas no Windows. Se não houver áudio, confirme primeiro o dispositivo e o volume do Windows, depois execute o teste de síntese. Uma falha de voz não comprova falha da IA: confira se o texto apareceu no chat.

Durante preparação do áudio o avatar pode pensar; durante reprodução, fala. A mandíbula, lábios e face acompanham o estado de fala por animação. A versão atual **não sincroniza fonemas individuais** com o conteúdo narrado. O ajuste de piscar/fala por fonemas pode aparecer desabilitado na aba Avatar 3D: os clipes do modelo controlam essas animações.

Pressione **Esc** para cancelar a apresentação em andamento. Esse atalho trata a apresentação; para cancelamento do trabalho de agente por uma ferramenta externa, use a ação `cancel` da API.

## 7. Usar o microfone

Em **Entrada de Voz / Microfone**:

1. Escolha o mecanismo de reconhecimento e o idioma.
2. Atualize a lista e selecione o microfone desejado.
3. Confira taxa de amostragem e canais compatíveis com o mecanismo.
4. Use **Testar Captação do Microfone** e fale uma frase.
5. Ative escuta contínua se quiser detecção automática e salve.

Confira permissões do Windows e se o microfone está silenciado. Em máquinas com vários dispositivos, confirme o nome/índice após trocar uma porta USB. A escuta pausa durante transcrição, resposta e fala do próprio Assistente, retomando ao terminar. Supressão de eco reduz realimentação, mas não garante isolamento acústico em todo ambiente.

O teste de captação confirma entrada de som; transcrição depende também do mecanismo configurado e de suas credenciais/serviço. Não suponha que todos os mecanismos funcionem sem rede.

## 8. Escolher e adicionar personagens

O pacote inclui Professor, Médico, Engenheiro, Programador, Dona de casa, Empresário, Padre, Criança, Bebê e Robô. A profissão muda a aparência; não equivale a uma validação profissional das respostas.

Na geração v4, todos possuem corpo completo sob roupas separadas. Mandíbula, pálpebras, olhos e dedos são articulados por esqueleto, com movimentos de ombro/clavícula nos gestos de braço. É uma aproximação visual, sem simulação física de músculos/tecidos ou rastreamento do olhar do usuário.

Para adicionar um personagem, copie um modelo `.glb` ou `.gltf` e seus recursos para uma subpasta de `AVATARES` ao lado do programa e clique em `↻`. Modelos próprios precisam estar orientados e animados de forma compatível. Um arquivo quebrado pode ser recusado ou substituído pelo professor padrão; consulte a dica do seletor. O [guia técnico](../professor-virtual-3d.md#pasta-avatares-e-inclusão-de-novos-personagens) mostra manifestos e clipes.

A IA também pode produzir tags como `[sorriso]`, `[aplausos]` e `[levantar mao direita]`. Elas são removidas do texto pronunciado e acionam gestos na apresentação. Veja [comandos e exemplos](../avatar-comandos-ia.md). Sem fala automática, a apresentação usa tempo estimado de leitura, sem abrir serviço de voz.

## 9. Câmera e Kinect

Em **Vídeo**, habilite câmera, Kinect ou ambos. As seleções são independentes. Atualize dispositivos, escolha cada equipamento e use **Testar dispositivo** antes de salvar.

A câmera fornece imagem RGB local usando drivers VFW; nem toda câmera disponível em outros programas aparece nessa interface. Kinect v1/Xbox 360 exige SDK local e hardware compatível para profundidade/esqueleto/gestos. Não há servidor de vídeo por IP nessa aba.

Com vários equipamentos, selecione explicitamente o desejado. Nomes/índices podem mudar após trocar portas ou drivers. Desmarcar Kinect preserva seus ajustes e desliga os recursos dele, mesmo com câmera habilitada. Uma falha em um equipamento não impede a tentativa de iniciar o outro.

O teste de software sem Kinect físico não comprova captura simultânea real. Confirme o funcionamento com seus equipamentos antes de usar em atendimento.

## 10. Jarvis e banco de dados

**JARVIS Residencial** configura URL, chave e modo do servidor Jarvis existente. Use o teste próprio antes de solicitar ações no ambiente. Autorize somente um servidor conhecido; ações do agente podem interagir com os dispositivos configurados.

**Banco de Dados** preserva campos MySQL/PostgreSQL. Preencher esses campos não cria um banco nem implica que todas as respostas estejam consultando esses dados. A utilização depende dos componentes e serviços associados ao projeto.

## Integração com outros programas

Use a versão atual compilada com a nova API:

1. Abra **Configurações → Integração externa**.
2. Marque **Permitir integração por DLL e socket**.
3. Para ferramentas no mesmo computador, mantenha endereço `127.0.0.1` e inclua `127.0.0.1` em **IPs permitidos**.
4. Escolha a porta, inicialmente `18766`. Se outro programa a estiver usando, informe uma porta livre e atualize o cliente.
5. Clique em **Gerar novo token**. Use **Mostrar token** somente para copiá-lo à ferramenta autorizada.
6. Informe cada IP permitido em uma linha. A lista aceita apenas endereços IPv4 individuais; não use `*`, nomes de máquinas ou faixas CIDR.
7. Salve. Reabra a configuração e confira o estado exibido: ativo, desativado ou motivo de falha ao iniciar.
8. Configure na ferramenta cliente endereço, porta e token. Mantenha o Assistente aberto.

Na janela estreita de configurações, use as setas da barra de abas para chegar a **Integração externa**. Role o conteúdo dessa aba para ver todos os campos e o estado do serviço.

Para outro computador, o endereço de escuta precisa corresponder à interface de rede do Assistente ou ser `0.0.0.0`. Inclua o IP real da ferramenta na lista, confira o firewall e use rede privada/VPN confiável. O token autentica, mas este socket **não cifra o tráfego**. Não exponha a porta diretamente na Internet.

A DLL exige a mesma autorização. Escolha DLL de 32 bits para programa cliente de 32 bits e de 64 bits para cliente de 64 bits. Isso depende da ferramenta chamadora, não da arquitetura do Windows.

Para revogar o acesso, desative a integração ou gere um novo token e salve. Ao trocar token, atualize as ferramentas autorizadas. O novo token vale para pedidos seguintes; uma ação já aceita pode continuar. O token salvo usa proteção do Windows ligada ao contexto do usuário/máquina; não trate a configuração copiada como token portável.

Ferramentas autorizadas podem consultar estado, listar/selecionar avatares, enviar perguntas, acompanhar respostas, solicitar fala/gestos e cancelar trabalhos. Não existem permissões individuais por ação nesta versão. Os detalhes para desenvolvimento estão nos guias [DLL](../DLL/README.md) e [socket](../Socket/README.md).

O protótipo antigo de texto bruto na porta 18765 não é iniciado nessa versão. Aplicativos Android antigos precisam ser adaptados para JSON autenticado; não há APK atualizado validado nesta entrega.

## Solução de problemas

| Sintoma | O que conferir |
| --- | --- |
| Não aparece a aba Integração externa | Abra o executável compilado das fontes atuais; o setup 0.120 é anterior à API |
| O avatar aparece, mas não responde | Provedor, modelo, URL e credencial; teste o provedor e a conexão |
| Texto funciona, mas não há voz | Fala automática, volume/dispositivo de saída e teste de síntese |
| Boca não se move | Use modelos v4 correspondentes ao programa e confira se há reprodução real de áudio; espera/preparação usa outro estado |
| Dedos/olhos não se movem em modelo próprio | Confirme esqueleto e clipes; não basta o nome do arquivo ser igual ao modelo incluído |
| Microfone não transcreve | Permissão do Windows, mute, dispositivo correto, teste de captação e serviço de reconhecimento |
| Câmera não aparece | Atualize dispositivos e confira compatibilidade VFW; confirme após trocar portas/drivers |
| Integração não inicia | Token com 64 hexadecimais, lista de IPs válida, endereço local e porta livre; reabra a aba para ler o estado |
| Cliente recebe `unauthorized` | Token atual exato; em socket envie em cada pedido, em DLL no argumento próprio |
| Cliente é desconectado imediatamente | IP real pode estar fora da lista; token correto não dispensa IP permitido |
| Cliente recebe `busy` | Aguarde IA/fala/transcrição ou feche a configuração; consulte o trabalho em andamento |
| `get_job` retorna `not_found` | ID incorreto, reinício ou remoção após novos trabalhos; não reenvie automaticamente uma pergunta antiga |
| DLL não carrega | Arquitetura do processo chamador e caminho absoluto da DLL |
| Desconectou após enviar um comando | O resultado pode ser desconhecido; confira o aplicativo antes de repetir uma ação |

Ao relatar um problema, informe qual executável/pacote abriu, o perfil do avatar, o passo que falhou e a mensagem exibida. Não inclua tokens, senhas ou seu arquivo completo de configuração.

## Limites desta versão

Há testes de TCP/ABI e da janela real com provedor local simulado. Isso não comprova todas as contas comerciais, conexão entre computadores, microfone/Kinect em seu ambiente ou todo driver gráfico. A boca acompanha a fala por ciclo animado, sem visemas por fonema; o olhar é procedural. Integração é TCP IPv4 autenticado, sem TLS, áudio por socket ou atendimento paralelo de várias conversas.
