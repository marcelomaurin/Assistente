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
