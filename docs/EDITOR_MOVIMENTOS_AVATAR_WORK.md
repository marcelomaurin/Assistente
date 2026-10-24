# Editor de Movimentos do Avatar — especificação e continuidade no Work

Data: 24/10/2026. Repositório: marcelomaurin/Assistente. Branch de desenvolvimento: feature/editor-movimentos-avatar. Último commit conhecido antes deste documento: aa99820c99a9d521a4b3b028f3eeabd348ec1350.

## Objetivo
Criar aplicativo independente em Lazarus/Free Pascal com Castle Game Engine, integrado ao mesmo avatar 3D do Assistente, para editar visualmente animações articuladas e salvá-las em arquivos externos. Não exigir Blender nem recompilar o Assistente para adicionar ou modificar movimentos. Preservar integralmente as tags existentes, que continuam sendo o gatilho de execução.

## Contrato de integração
Fluxo: texto/apresentação -> tag existente [nome] -> catálogo AVATARES/movimentos.json -> campo animation_file -> arquivo JSON externo na pasta movimentos relativa ao catálogo -> interpretador de trilhas -> rig 3D do professor. Não confundir o catálogo de tags com os arquivos de animação. Manter aliases, tags, modos, clipes legados e sincronização com fala. A IA poderá propor tags ou sequências, mas os movimentos devem passar por validação antes de gravar. Nunca executar código arbitrário contido no JSON.

## Fontes existentes
- tools/motion_editor/motion_editor.lpr: protótipo de janela, viewport do professor, abertura e gravação JSON, seleção de osso/eixo, edição de ângulo e tempo, criação de keyframes.
- src/professor_view.pas: TProfessorView e ExecuteMovement; usa catálogo e TPresentationScene.ExecuteAnimation.
- src/movement_animation.pas: TMotionAnimation, TMotionTrack e TMotionKeyframe, leitor validado e interpolação.
- src/movement_catalog.pas: tags, aliases, catálogo, animation_file e validação.
- src/presentation_joints.pas e src/presentation_joint_tags.pas: integração com rig, execução e limites das articulações.
- scripts/build_professor.ps1: referência de compilação Windows com Lazarus, Castle e dependências.

## Formato atual
JSON com format=assistente-motion, version=1, name, duration_ms, loop, return_to_base, interpolation (linear ou smoothstep) e tracks. Cada track tem bone, axis (x/y/z) e keyframes ordenados com time_ms e angle. Suporta várias articulações e várias passagens temporais, inclusive oscilações. Limitações atuais: um único eixo por osso, uma trilha por osso, rotação angular escalar; não há quaternions, translação ou curvas Bézier. Qualquer extensão deve ser versionada, manter compatibilidade v1 e ser implementada também no player.

Exemplo ilustrativo:
```json
{"format":"assistente-motion","version":1,"name":"aceno","duration_ms":2000,"loop":false,"return_to_base":true,"interpolation":"smoothstep","tracks":[{"bone":"upperarm01.R","axis":"z","keyframes":[{"time_ms":0,"angle":0},{"time_ms":500,"angle":25},{"time_ms":1000,"angle":10},{"time_ms":1500,"angle":25},{"time_ms":2000,"angle":0}]}]}
```
O nome de osso e limites devem ser confirmados contra o modelo e JointAngleLimit antes de usar.

## Estado real e lacunas
O protótipo foi commitado, mas não há confirmação de compilação ou execução local. O botão 'Prévia no avatar' ainda apenas informa que a prévia não está conectada ao rig. A linha do tempo mostra valores da trilha selecionada, mas não aplica a pose ao avatar. Não existe manipulação 3D direta por clique/arraste, gizmos, seleção visual de ossos, painel de trilhas, play/pause/stop, undo/redo, exclusão de keyframes, controle de curvas, persistência da tag no catálogo ou geração por IA. O salvamento precisa ser revisto para garantir rollback atômico e liberar recursos mesmo em exceções. Conferir assinatura de FileUtil.CopyFile, dependências de compilação, ciclo de vida de TProfessorView e comportamento do rig. Não afirmar que está pronto sem compilar e testar.

## Plano de implementação para o Work
1. Sincronizar repositório local em C:\\projetos\\maurinsoft\\Assistente e conferir branch, working tree e documentação existente; preservar alterações locais.
2. Inspecionar arquivos listados, modelo glTF real e nomes de ossos, identificar API pública de pose no TPresentationScene. Criar projeto Lazarus compilável do editor e script próprio de build usando as dependências existentes.
3. Implementar prévia em tempo real: avaliar todas as trilhas no mesmo instante, aplicar poses ao rig, limpar estados anteriores, controlar play/pause/stop, scrub, loop, retorno à pose base e sincronização temporal. Evitar que animação idle sobrescreva os quadros do editor.
4. Criar painel de hierarquia de ossos, seleção no viewport quando suportada, controles de rotação por eixo, gizmos ou manipuladores equivalentes, e gravação de keyframes múltiplos por articulação. Garantir edição de N passagens e articulações simultâneas.
5. Criar timeline multitrilha com marcadores, mover/copiar/excluir keyframes, duração, interpolação, undo/redo, atalhos, zoom e visualização do instante atual.
6. Implementar Novo/Abrir/Salvar/Salvar como, validação rigorosa, backup seguro, recuperação de erros e proteção contra perda de dados; salvar JSON compatível com player atual. Testar abrir->editar->salvar->reabrir->reproduzir.
7. Integrar cadastro de tag, ID, aliases e animation_file no AVATARES/movimentos.json, preservando tags existentes e sem alterar o gatilho do Assistente. Recarregar catálogo sem recompilar.
8. Preparar interface para geração assistida por IA de movimentos em keyframes, com revisão humana e validação de limites; não presumir que a IA já está conectada.
9. Criar testes de parser, limites, trilhas simultâneas, interpolação, arquivos inválidos, round-trip e compatibilidade com movimentos existentes; executar build real Windows e smoke test do viewport. Documentar resultados e pendências.
10. Atualizar docs com arquitetura, uso, JSON, tags, exemplos, build e troubleshooting; publicar na branch apropriada e integrar na main apenas depois de validar e sem sobrescrever mudanças concorrentes.

## Critérios de aceite
O editor abre o mesmo avatar do Assistente; alterar uma articulação muda imediatamente o modelo; o usuário cria movimentos com múltiplos ossos e keyframes; reproduz a sequência no editor; salva e reabre o JSON; vincula-o a uma tag existente ou nova; a tag aciona a mesma animação no Assistente sem recompilar; todos os movimentos legados continuam funcionando; build e testes têm evidências registradas.

## Instrução de retomada
No ChatGPT Work, abrir C:\\projetos\\maurinsoft\\Assistente, ler este documento e os fontes relacionados, verificar diferenças entre disco e GitHub, implementar por etapas, compilar/testar no ambiente Windows e registrar commits. Não considerar protótipo como produto concluído.