# Editor de Movimentos do Avatar — especificação e continuidade no Work

Data: 24/10/2026. Repositório: marcelomaurin/Assistente. Branch de desenvolvimento: feature/editor-movimentos-avatar. Último commit conhecido antes deste documento: aa99820c99a9d521a4b3b028f3eeabd348ec1350.

## Objetivo
Criar aplicativo independente em Lazarus/Free Pascal com Castle Game Engine, integrado ao mesmo avatar 3D do Assistente, para editar visualmente animações articuladas e salvá-las em arquivos externos. Não exigir Blender nem recompilar o Assistente para adicionar ou modificar movimentos. Preservar integralmente as tags existentes, que continuam sendo o gatilho de execução.

## Contrato de integração
Fluxo: texto/apresentação -> tag existente [nome] -> catálogo AVATARES/movimentos.json -> campo animation_file -> arquivo JSON externo na pasta movimentos relativa ao catálogo -> interpretador de trilhas -> rig 3D do professor. Não confundir o catálogo de tags com os arquivos de animação. Manter aliases, tags, modos, clipes legados e sincronização com fala. A IA poderá propor tags ou sequências, mas os movimentos devem passar por validação antes de gravar. Nunca executar código arbitrário contido no JSON.

## Fontes existentes
- tools/motion_editor/motion_editor.lpr: janela com tema MultiCNC, viewport do professor, abrir/salvar JSON v1/v2, seleção de membros no avatar/lista, anéis XYZ, campos de ângulo/tempo, poses, scrub e vistas CAD.
- src/professor_view.pas: TProfessorView e ExecuteMovement; usa catálogo e TPresentationScene.ExecuteAnimation.
- src/movement_animation.pas: TMotionAnimation, TMotionTrack e TMotionKeyframe, leitor validado e interpolação.
- src/movement_catalog.pas: tags, aliases, catálogo, animation_file e validação.
- src/presentation_joints.pas e src/presentation_joint_tags.pas: integração com rig, execução e limites das articulações.
- scripts/build_professor.ps1: referência de compilação Windows com Lazarus, Castle e dependências.

## Formato atual
JSON com format=assistente-motion, version=1, name, duration_ms, loop, return_to_base, interpolation (linear ou smoothstep) e tracks. Cada track tem bone, axis (x/y/z) e keyframes ordenados com time_ms e angle. Suporta várias articulações e várias passagens temporais, inclusive oscilações. O contrato v1 usa um único eixo por osso. A revisão 3D adiciona o contrato v2, com `axis: "xyz"`, `rotation_deg: [x,y,z]` e interpolação por quaternions; mantém uma trilha por osso. Translação de ossos e curvas Bézier continuam pendentes. Qualquer extensão deve ser versionada, manter compatibilidade v1 e ser implementada também no player.

Exemplo ilustrativo:
```json
{"format":"assistente-motion","version":1,"name":"aceno","duration_ms":2000,"loop":false,"return_to_base":true,"interpolation":"smoothstep","tracks":[{"bone":"upperarm01.R","axis":"z","keyframes":[{"time_ms":0,"angle":0},{"time_ms":500,"angle":25},{"time_ms":1000,"angle":10},{"time_ms":1500,"angle":25},{"time_ms":2000,"angle":0}]}]}
```
O nome de osso e limites devem ser confirmados contra o modelo e JointAngleLimit antes de usar.

## Estado real e lacunas
Em 24/10/2026 o protótipo foi compilado em i386-win32 com o mesmo script dos programas principais. A construção da janela usa `CreateNew`, sem exigir um formulário de recurso inexistente. O botão **Reproduzir movimento** valida a definição e executa as trilhas no motor de colisão compartilhado. O salvamento valida um temporário privado, cria backup e substitui o destino sem apagar antes o original; preserva loop, retorno e interpolação. Cancelar o diálogo libera os recursos.

Na revisão 3D, a linha do tempo aplica a pose ao avatar; há seleção visual, anéis XYZ, campos simultâneos, gravação de poses, reprodução e parada. A câmera oferece sete vistas, projeção ortográfica/perspectiva, órbita, pan, zoom e rolagem, com cores/layout do MultiCNC. Continuam pendentes painel de trilhas, pausa/retomada editável, undo/redo, exclusão de keyframes, curvas, persistência da tag no catálogo e geração por IA. O projeto Lazarus `.lpi` continua pendente; a compilação verificada usa `scripts/build_presentations.py --target motion-editor`. Não considerar o protótipo um editor completo. Evidências e limites constam no [relatório](VALIDACAO_2026-10-24.md).

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