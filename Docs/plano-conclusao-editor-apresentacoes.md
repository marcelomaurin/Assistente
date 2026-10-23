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
