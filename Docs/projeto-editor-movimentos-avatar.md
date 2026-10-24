# Editor de Movimentos do Avatar — projeto de implementação

## Objetivo
Criar aplicativo desktop independente em Lazarus/Free Pascal para abrir o mesmo avatar 3D do Professor Virtual, manipular articulações com mouse e controles numéricos, construir uma linha do tempo de quadros-chave e salvar animações no formato `assistente-motion` versão 1, sem recompilar o Assistente.

## Integração com o repositório
- Projeto: `tools/motion_editor/motion_editor.lpi` e `motion_editor.lpr`.
- Renderização: reutilizar a configuração de Castle Game Engine e a malha/esqueleto do Professor Virtual, **sem duplicar rig nem converter ossos**.
- Catálogo existente: `AVATARES/movimentos.json`.
- Arquivos de saída: `AVATARES/movimentos/<nome>.json`.
- Parser/limites: compartilhar `src/movement_animation.pas` e `src/presentation_joint_tags.pas`.
- O editor deve abrir o catálogo, carregar `animation_file` e atualizar a associação da tag somente quando o usuário confirmar.
- Não sobrescrever movimentos existentes sem confirmação; usar escrita atômica com arquivo temporário, backup e validação após gravação.

## Interface
1. **Painel esquerdo:** catálogo de tags, pesquisa, novo/duplicar movimento, selecionar avatar e animação.
2. **Centro:** viewport 3D com avatar, câmera orbital, zoom, grade e gizmos X/Y/Z. Seleção por clique no osso, destaque visual e opção de exibir hierarquia.
3. **Painel direito:** osso selecionado, eixo, ângulo em graus, limite permitido, rotação absoluta relativa à pose base, interpolação e botões adicionar/remover quadro-chave.
4. **Rodapé:** timeline em milissegundos, duração, reprodução, pausa, loop, avançar quadro, posição atual e trilhas por osso.
5. **Menu:** Abrir, Novo, Salvar, Salvar como, Validar, Reverter, Exportar, Configurações.

## Contrato de animação
```json
{
  "format": "assistente-motion",
  "version": 1,
  "name": "Meu movimento",
  "duration_ms": 2400,
  "loop": false,
  "return_to_base": true,
  "interpolation": "smoothstep",
  "tracks": [
    {
      "bone": "upperarm01.R",
      "axis": "z",
      "keyframes": [
        {"time_ms": 0, "angle": 0},
        {"time_ms": 600, "angle": 35},
        {"time_ms": 2400, "angle": 0}
      ]
    }
  ]
}
```

## Regras funcionais
- Arrastar gizmo altera a pose na viewport; botão **Gravar quadro** adiciona/atualiza `time_ms` e `angle` na trilha correspondente.
- A prévia usa a mesma interpolação `MotionAngleAt` do runtime, não um simulador diferente.
- Não permitir ângulo fora de `JointAngleLimit`, trilha com osso repetido, quadros fora da duração ou tempo não crescente.
- Ao mudar de frame, reconstruir a pose desde a base, evitando acumulação de rotações.
- `return_to_base` deve ser visível e editável; poses persistentes precisam de semântica explícita.
- Expressões faciais e gestos de dedos só podem ser editados quando o rig efetivamente expuser os ossos/blendshapes necessários. Não inventar suporte facial.
- Preservar modos legados (`smile`, `reset`, `stop`, `clear_pose`) sem forçar arquivos JSON.
- Mostrar claramente movimentos com arquivo externo e movimentos legados.

## Etapas verificáveis
1. Janela Lazarus + Castle com **avatar real carregado** e câmera navegável.
2. Seleção de osso e manipulação visual respeitando limites.
3. Timeline e gravação/edição de keyframes.
4. Leitura/gravação compatível com parser atual; atualizar catálogo com backup.
5. Prévia de movimento e comparação visual no Professor Virtual.
6. Build automatizado Windows e testes de round-trip JSON (abrir→salvar→abrir).

## Critérios de aceite
- Criar novo gesto pelo editor, posicionar braço do avatar, inserir 3 quadros-chave, reproduzir e salvar.
- A tag nova deve funcionar no Assistente apontando para o JSON salvo, sem alterar código Pascal.
- Abrir `aceno.json`, modificar, salvar e reproduzir no Professor Virtual.
- Arquivos inválidos geram erro amigável sem corromper o catálogo.
- O aplicativo deve funcionar sem Blender e sem recompilação para adicionar animações.

## Estado
Esta especificação inicia o projeto; **a interface 3D, compilação e testes ainda não estão implementados**. A branch de desenvolvimento não altera a main.
