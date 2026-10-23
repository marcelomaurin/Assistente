# Plano para concluir o Editor de Apresentações do Assistente

Atualizado em 23/10/2026. Documento de planejamento; itens abaixo não devem ser considerados concluídos sem validação.

## Situação
O interpretador inicial `src/presentation_tags.pas` foi relatado como publicado na `main`. Confirmar no código e compilar. O editor independente e a reprodução multimídia integrada continuam pendentes.

## Objetivo
Editor independente em Lazarus: usuário escreve roteiro, IA insere tags de movimento automaticamente, usuário posiciona imagens, vídeos e slides, exporta pacote ZIP versionado `.pva`, e o Assistente instalado executa fala, gestos e mídias.

## Etapas pendentes
1. **Formato do pacote:** manifesto JSON, roteiro UTF-8, assets, hashes, versão e caminhos relativos; validação contra ZIP traversal.
2. **Tags:** integrar parser de apresentação ao parser de movimentos; preservar os 40 comandos existentes e definir formalmente tags de abrir/fechar mídia e controlar slides.
3. **Editor Lazarus:** edição, salvar/abrir, inserir mídia na posição do cursor, botões de slide, desfazer/refazer, lista de recursos e validação.
4. **IA:** reutilizar componentes ChatGPT do projeto; inserir movimentos sem reescrever texto ou alterar posições de mídias; permitir regeneração e desfazer.
5. **Articulações:** tags parametrizadas por osso, eixo, ângulo, duração e interpolação; limites conforme rig do avatar.
6. **Executor:** Assistente recebe caminho `.pva`, valida, carrega e executa roteiro com pausa, retomada e cancelamento.
7. **Mídia única:** abrir imagem/vídeo/apresentação substitui a anterior; fechar mídia encerra a ativa sem exigir nome.
8. **PowerPoint:** slide inicial, próximo, anterior e slide específico; definir renderização confiável e dependências.
9. **Sincronização:** tags executadas no ponto do roteiro; TTS não pronuncia tags; boca continua exclusivamente sob controle da fala.
10. **Empacotamento e execução:** exportar somente recursos referenciados, validar integridade e chamar o Assistente instalado para prévia.
11. **Testes:** parser, mídia única, slides, regeneração, ZIP inválido, cancelamento, fala e gestos simultâneos, compilação e execução real.
12. **Documentação e entrega:** README, catálogo de tags, formato `.pva`, manual, exemplos, changelog, CI e commits na `main`.

## Critérios de aceite
Um roteiro deve receber tags automáticas da IA, preservar mídia posicionada manualmente, exportar pacote único e ser executado pelo Assistente com fala, movimentos, navegação de slides e somente uma mídia visual aberta. A boca deve seguir o áudio independentemente dos gestos. Compilação e testes precisam passar.

Documento Google Docs: https://docs.google.com/document/d/1x2jXgRQilURskN3N1wooBeG8CyNvKXO0ZbWg0JaUGzY/edit
