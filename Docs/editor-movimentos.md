# Editor de Movimentos — prévia 3D

O Editor de Movimentos é um aplicativo independente que usa o mesmo avatar e a mesma proteção de colisão do Assistente. A revisão 3D acrescenta seleção direta dos membros, anéis de rotação e poses com X, Y e Z simultâneos. O movimento altera o esqueleto real; mãos e antebraços acompanham a rotação do braço.

## Criar e experimentar um movimento

1. Escolha o tempo na linha do tempo antes de editar a pose.
2. Clique num ponto do corpo ou escolha um membro na lista. Os dedos ficam disponíveis na lista para evitar pontos sobrepostos nas mãos.
3. Arraste um dos anéis de rotação ou ajuste os campos X, Y e Z. Os valores representam graus nos eixos locais, relativos à pose de repouso do membro. Arrastar fora dos anéis ou com o botão do meio orbita a câmera; o botão direito desloca a vista; a roda aproxima e afasta; duplo clique reenquadra. Alt + botão do meio gira a câmera em torno do eixo de visão.
4. Clique em **Gravar pose neste tempo**. O editor registra os membros alterados e os membros já presentes no movimento. Um quadro no mesmo tempo substitui o anterior. Na primeira gravação, cria também os extremos da trilha: repouso no início e pose atual no fim, exceto quando a própria gravação substitui um desses extremos.
5. Mova a linha do tempo para conferir as poses interpoladas. Mudar o tempo reconstrói a pose gravada; ajustes ainda não gravados são descartados.
6. Use **Reproduzir movimento**. **Parar / editar pose atual** mantém a pose exibida para edição; **Restaurar pose do avatar** retorna ao repouso sem apagar quadros gravados.
7. Use **Salvar movimento** e escolha um JSON. Prefira um nome novo ao experimentar. **Abrir movimento** lê arquivos antigos e novos.

A proteção de colisão também atua durante o arraste e a navegação na linha do tempo. Quando um deslocamento solicitado não é seguro, o editor mantém a última parte segura da trajetória e informa o par de volumes. A pose exibida pode então diferir da solicitada. Não é uma simulação física de roupas ou malhas. Os ângulos são limitados por articulação; a edição usa rotação FK, preservando comprimentos, posições locais e escalas dos ossos. Não há controle IK de mãos ou pés nesta prévia.

## Vistas e padrão MultiCNC

A ferramenta usa os componentes `TSuiteHeader`, `TSuiteButton` e os ícones do projeto MultiCNC/MultiSuite: cabeçalho azul em degradê, ações azuis, gravação verde, painéis brancos, fundo claro e tipografia Segoe UI. Os fontes foram incorporados ao repositório; não é preciso instalar o MultiCNC.

A navegação foi adaptada de `src/simucnc/multicnc_print3d_view.pas`: arraste para orbitar (0,6 grau por pixel), botão direito para pan e zoom de 1,12 por passo da roda. No editor, um arraste sobre o anel manipula o membro, preservando a navegação fora dos anéis. A câmera considera o eixo Y vertical do avatar, enquanto o simulador CNC trabalha com Z vertical.

Use o seletor **Vista** para Frontal, Traseira, Esquerda, Direita, Superior, Inferior e Isométrica. Os atalhos são Ctrl+1 a Ctrl+7 na mesma ordem; Ctrl+0 ajusta o enquadramento. A opção Perspectiva 3D abre uma vista isométrica com profundidade em perspectiva. O outro seletor alterna projeção ortográfica e perspectiva. **Z −15°** e **Z +15°** giram a câmera em torno da direção de observação, sem alterar a pose. O indicador de eixos acompanha a orientação: X vermelho, Y verde e Z azul.

Mover a câmera e trocar de vista preservam os quadros gravados e a pose. O JSON contém a animação, sem incluir o enquadramento da câmera.

## Formato e integração

O leitor continua aceitando `assistente-motion` versão 1, com um eixo por trilha. Poses com vários eixos são gravadas na versão 2:

```json
{
  "format": "assistente-motion", "version": 2,
  "name": "braco_3d", "duration_ms": 1000,
  "loop": false, "return_to_base": true, "interpolation": "smoothstep",
  "tracks": [{"bone": "upperarm01.L", "axis": "xyz", "keyframes": [
    {"time_ms": 0, "rotation_deg": [0, 0, 0]},
    {"time_ms": 1000, "rotation_deg": [15, 10, 25]}
  ]}]
}
```

A ordem de composição é `Qz * Qy * Qx`; a rotação resultante é aplicada após a rotação local de repouso. Na versão 2, a interpolação usa quaternions e o arco mais curto, com a mesma avaliação na linha do tempo e no reprodutor. A versão 1 mantém a interpolação escalar, inclusive em trajetórias com diferença maior que 180 graus. Os dois formatos preservam duração, retorno, loop e interpolação ao abrir e salvar.

O salvamento valida o arquivo temporário antes da substituição atômica e cria `.bak` quando sobrescreve um destino. Limites: 1 MiB, 64 trilhas, uma trilha por membro, 2 a 256 quadros por trilha e duração entre 50 e 60000 ms.

Salvar JSON não cadastra automaticamente uma tag. As 53 receitas internas calibradas continuam tendo prioridade sobre arquivos externos de referência. Consulte [Movimentos JSON](movimentos-json.md#integração-de-animações-externas-validada-em-24102026). Arquivos v2 exigem os programas recompilados com esta revisão; instalações anteriores só reconhecem v1.

## Estado e instalação

Disponíveis: seleção no avatar/lista, rotação XYZ por anéis e campos numéricos, câmera orbital, gravação de poses, navegação visual na linha do tempo, abrir/salvar e reprodução protegida. Ainda pendentes: undo/redo, exclusão de quadros, editor de curvas e trilhas visuais, seleção de outro avatar pela interface, picker corporal desenhado, IK, geração por IA e cadastro de tags.

O instalador 0.214 preserva JSON existentes em `AVATARES/movimentos` ao reinstalar e desinstalar. Consulte [Instalação 0.214](INSTALACAO_0214.md). O executável de desenvolvimento está em `build/presentations-0214-cad/motion_editor.exe`, com os recursos na pasta `AVATARES` ao lado.
