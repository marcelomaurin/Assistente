# Conclusão do Editor de Apresentações do Assistente

Atualizado em 23/10/2026. O parser inicial foi confirmado no código e integrado à implementação. O status abaixo distingue implementação de evidência de execução.

## Objetivo implementado

Editor independente Lazarus para escrever roteiros, gerar gestos pela IA preservando o texto e as mídias, posicionar recursos, exportar ZIP versionado `.pva` e executar no Assistente com fala, gestos e mídias.

## Entrega e validação

| Etapa | Implementação e evidência |
| --- | --- |
| 1. Formato do pacote | Manifesto JSON v1, roteiro UTF-8, recursos relativos e SHA-256. Streams e expansão limitados, validação de cabeçalhos/caminhos ZIP. Testes de ida/volta e 22 pacotes adversariais aprovados. |
| 2. Tags | Parser unificado preservando os 40 comandos anteriores; tags de mídia, slides e articulações documentadas. Regressão anterior aprovada. |
| 3. Editor Lazarus | Abrir/salvar PVA, edição, inserção no cursor, navegação de slides, desfazer/refazer, recursos e validação. Teste da janela nativa e captura de interface. |
| 4. IA | Componente TCHATGPT existente; geração/regeneração, preservação exata da projeção sem gestos, cancelamento e alteração como uma operação de desfazer. Provedor HTTP local aprovado, incluindo UTF-8 e recusa de reescrita. |
| 5. Articulações | Osso, eixo, ângulo, duração e interpolação; allowlist e limites conservadores do rig incluído; mandíbula/lábios excluídos. Movimento real da cabeça observado no renderer. |
| 6. Executor | Argumento `.pva` ou `--presentation`, validação antes da extração, pausa/retomada por P e cancelamento por Esc. Teste integrado da janela aprovado. |
| 7. Mídia única | Abrir substitui/encerra a anterior; fechar é idempotente. PNG e AVI reais testados. |
| 8. PowerPoint | Automação COM de PPTX, abertura no slide 1, próximo/anterior/específico e limites. Requer PowerPoint funcional na sessão interativa. PPTX real aprovado na sessão do usuário: slide inicial, próximo, anterior, específico, limites e fechamento. |
| 9. Sincronização | Eventos na fila confirmada pelo thread da interface; tags removidas do TTS; mandíbula depende de áudio em reprodução, independentemente dos gestos. Boca silenciosa verificada no renderer. |
| 10. Empacotamento e prévia | Exportação apenas dos recursos referenciados; validação de integridade; editor inicia o Assistente selecionado com o PVA. Temporários privados e limpeza no término/cancelamento. |
| 11. Testes | Parser, formato, ZIP inválido, IA local, editor, imagem/vídeo, pausa, cancelamento e compilação Win32. Áudio WAV real, pausa/retomada, cancelamento pausado e PPTX real aprovados na sessão do usuário. O relatório registra as evidências. |
| 12. Documentação e entrega | Manual, catálogo, formato PVA, exemplo, changelog, build e workflow manual para runner Windows preparado. O histórico Git registra a entrega local. |

## Arquivos de referência

- [Manual e comandos de build/teste](editor-apresentacoes.md)
- [Catálogo de tags](tags-apresentacoes.md)
- [Formato PVA v1](formato-pva.md)
- [Changelog](../CHANGELOG-apresentacoes.md)
- Exemplo em `examples/apresentacoes/`.
- Executáveis compilados em `build/presentations/`.

## Critérios de aceite

O aceite exige gerar gestos preservando mídia manual, exportar pacote único e reproduzir fala, gestos, slides e uma única mídia visual. Os testes não utilizam credenciais reais nem comprovam qualidade de voz de provedores externos. O workflow foi adicionado, mas só uma execução no runner configurado comprova seu funcionamento no GitHub.

Homologação local concluída em Windows Win32, incluindo navegação real de PPTX na sessão interativa. Office em conta de serviço/sessão isolada não foi homologado. O teste inicial nessa conta falhou por logon e foi repetido com sucesso na sessão do usuário.

Relatório: [validacao-apresentacoes.json](validacao-apresentacoes.json).

Documento Google Docs original: https://docs.google.com/document/d/1x2jXgRQilURskN3N1wooBeG8CyNvKXO0ZbWg0JaUGzY/edit


## Complemento — recursos temporais e identidade

Implementados áudio WAV/MP3/WMA, início opcional hh:mm:ss de vídeo/som, tags de escolha de avatar e voz e respectivos controles no editor. Som e mídia visual têm canais independentes. O avatar original é restaurado ao encerrar; a voz fica restrita ao worker da apresentação. A IA preserva essas escolhas. Testes adicionais verificam seek real, duração, som com imagem, troca/restauração de avatar e a voz enviada ao TTS.


## Complemento — visualização no painel de texto

Implementado painel visual dentro da área de conversa do Assistente para imagens, vídeos e slides. A área do avatar permanece visível e separada. O histórico e a digitação ficam ocultos somente durante a exibição visual, com o rascunho preservado e restaurado ao fechar, terminar ou cancelar. Som isolado não oculta o texto. O painel e a janela nativa incorporada do PowerPoint acompanham o redimensionamento. Testes nativos verificam ausência de sobreposição, restauração do texto/rascunho, navegação real dos slides e limpeza.


## Complemento — biblioteca RAG e execução selecionada pela IA

O salvamento no editor publica o PVA em %LOCALAPPDATA%/Assistente/RAG e gera um .res UTF-8 do mesmo nome com os textos sem tags de controle. Um monitor também detecta pacotes copiados diretamente para a biblioteca enquanto o Assistente estiver aberto. A consulta usa candidatos recuperados por termos e seleção estruturada pela IA configurada. Ao escolher um documento, o Assistente executa o pacote original; na ausência de correspondência, segue a conversa comum. Identificadores são limitados aos candidatos da consulta, o pacote é validado e mudanças do roteiro durante a seleção impedem execução desatualizada. O manual detalha os limites de recuperação e trechos.

Validados na sessão do usuário: publicação pelo editor, geração do .res, detecção externa em segundo plano, atualização/remoção, seleção pelo agente real usando IA HTTP local, ausência de correspondência, seleção inválida, cancelamento e pergunta pela janela real iniciando o PVA original com PowerPoint e avatar visível. O relatório registra essa execução.


## Complemento — blocos, eventos preparados e comandos de documentos

Implementados primeiro os controles do editor e sua validação nativa; depois, o Assistente foi validado com GOTO, chamadas com retorno, entrada direta em bloco, FIM e retenção do arquivo carregado. Eventos de voz, rosto, mão levantada e reconhecimento de pessoa são metadados preparados, sem disparadores de sensores. Os comandos digitados/transcritos carregam arquivos pelo nome e chamam blocos, distinguindo roteiros de documentos tradicionais de consulta. A busca privilegia nomes exatos e recusa aproximações ambíguas.

O teste na janela real confirmou reutilização do arquivo após término, FIM encerrando áudio/mídia, não execução dos eventos, troca de arquivo e RAG tradicional fornecendo conhecimento à IA. A transcrição é simulada no callback real; não houve teste físico de ASR. Sintaxe, decisões e limitações estão em [blocos-eventos-comandos.md](blocos-eventos-comandos.md).
