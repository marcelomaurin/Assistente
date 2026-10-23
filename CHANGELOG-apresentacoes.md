# Alterações — Editor de Apresentações

## 23/10/2026 — PVA v1 / Windows Win32

- Editor Lazarus independente com roteiro, recursos, inserção no cursor, abrir/salvar, validação e desfazer/refazer.
- Geração/regeneração de gestos pelo componente CHATGPT existente, com preservação exata de texto e mídia e cancelamento.
- Pacote ZIP PVA versionado, roteiro UTF-8, inventário SHA-256, limites de expansão e validação de caminhos/cabeçalhos.
- Parser combinado preservando os 40 comandos anteriores, mídia, slides e articulações limitadas.
- Executor integrado ao Assistente com fila de eventos, pausa/retomada, cancelamento e limpeza.
- Uma mídia ativa: imagens Lazarus, vídeo MCI e integração PowerPoint COM com navegação manual.
- Mandíbula controlada pelo estado real de reprodução, independentemente dos gestos.
- Build, CLI, exemplos, testes de regressão, testes nativos e workflow manual de CI.
- Validados PPTX real, navegação, limites e fechamento na sessão Windows do usuário; áudio WAV real com pausa/retomada e cancelamento durante pausa. Sessões Office de serviço/isoladas não são suportadas pelo teste.

## Complemento de recursos temporais e escolhas

- Início opcional hh:mm:ss para vídeo e áudio.
- Som WAV/MP3/WMA em canal independente da mídia visual, com fechar som.
- Tags avatar/voz, seleção no editor e restauração das escolhas originais.
- Voz selecionada antes da síntese, validação SAPI explícita e preservação pela IA.
- Término do roteiro aguarda vídeo/som; pausa e cancelamento continuam ativos.


### Visualização junto ao avatar

- Painel de imagens, vídeos e PowerPoint incorporado à área de conversa, acompanhando o tamanho da janela.
- Avatar visível ao lado dos recursos; histórico e digitação temporariamente ocultos, com rascunho preservado.
- Restauração da conversa ao fechar, terminar, cancelar ou falhar; áudio isolado mantém o texto visível.
- Testes nativos de layout, redimensionamento, restauração e slides reais incorporados.


### Biblioteca RAG de apresentações

- Salvamento no editor copia o pacote para AppData local/Assistente/RAG e gera .res UTF-8 com o texto do roteiro sem tags executáveis.
- Monitor em segundo plano detecta pacotes externos e atualizações; arquivos incompletos, inválidos e .res sem pacote não entram na seleção.
- Recuperação de candidatos por termos e escolha pela IA configurada, com seleção restrita aos documentos oferecidos.
- A seleção executa o PVA original com voz, avatar e mídias; ausência de correspondência mantém a conversa normal.
- Revalidação antes da reprodução e testes de publicação, monitor, UTF-8, alteração/remoção, cancelamento e roteamento real da janela.


### Blocos de comandos e documentos carregados

- Editor: inserir BLOCO, GOTO, chamadas com retorno, EVENT e FIM; prévia de um bloco; validação de nomes, referências, ciclos e expansão.
- Executor: principal termina na primeira declaração; chamadas curtas retornam; GOTO encerra após o destino; FIM termina toda a tarefa e fecha as mídias.
- Eventos de voz, rosto, mão levantada e reconhecimento de pessoa declarados e validados, sem consequência ou ligação com sensores.
- Comandos digitados/transcritos carregar arquivo e chamar bloco; busca por nome exato ou semelhante, com recusa de ambiguidade e tratamento do par PVA/RES.
- Roteiros UTF-8 .script/TXT/MD reconhecidos; documentos tradicionais de texto ficam como conhecimento e não executam tags.
- Arquivo carregado mantido após o término, revalidado a cada chamada; RAG tradicional substitui os blocos anteriores.
- Testes na ordem editor → Assistente, fala sem tags, FIM, comandos e contexto da IA. Documentação em Docs/blocos-eventos-comandos.md.
