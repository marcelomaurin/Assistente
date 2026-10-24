# Validação do editor 3D e do visual MultiCNC — 24/10/2026

A revisão acrescenta ao Editor de Movimentos a seleção de membros no avatar/lista, anéis XYZ, rotação simultânea dos três eixos, gravação de poses e navegação visual na linha do tempo. O esqueleto é o mesmo do Assistente, com a proteção de colisão compartilhada.

A interface incorpora os controles e ícones do projeto MultiCNC/MultiSuite: paleta, cabeçalho, botões, tipografia e organização dos painéis. A câmera adapta a navegação do simulador CNC ao eixo Y vertical do avatar. Há vistas frontal, traseira, esquerda, direita, superior, inferior e isométrica, projeção ortográfica/perspectiva, órbita, pan, zoom e rolagem. Veja o [guia de uso](editor-movimentos.md).

## Evidências

- Os quatro programas foram compilados em i386-win32: Assistente, Editor de Apresentações, ferramenta PVA e Editor de Movimentos.
- A suíte offline completa passou nas **44 verificações**, incluindo onze modelos, movimentos antigos, áudio, comandos, interface, PVA, fluxo de apresentações e RAG. Relatório e logs: `build/presentations-0214-cad/validation-report/result.json`.
- O teste de animações abriu os 41 recursos antigos, validou round-trip, backup e preservação do destino após erro; comparou a interpolação escalar e XYZ com o reprodutor; verificou 2.001 combinações de Euler/inversa, arquivos v2 inválidos, duração, retorno e loop.
- O teste da view real executou um recurso externo XYZ v2, conferiu a orientação por quaternion e validou fala/idle, meia velocidade, pausa, retorno e reset com colisão ativa.
- O teste nativo do editor selecionou um membro por projeção na tela, arrastou os anéis pelo mesmo sistema de eventos usado pelo controle 3D, verificou o movimento dos filhos do braço, a pose estática, gravação/reabertura v2, scrub e reprodução protegida. Conferiu as sete vistas e a base ortogonal da câmera, inclusive topo e fundo, pan, órbita, rolagem e enquadramento.
- O teste captura a interface e o avatar OpenGL em `motion-editor-layout.bmp` e `motion-editor-avatar.png`, ao lado dos executáveis; as imagens foram inspecionadas. Foram corrigidos o centro da projeção ortográfica e a escala/visibilidade dos anéis.
- O instalador 0.214 foi testado em uma pasta isolada: atualização real de 0.213, hashes dos arquivos, execução do editor instalado, SSL, PVA, 53 movimentos do Zé Gotinha em execução isolada e em sequência, reinstalação e desinstalação preservando os JSON editados e criados pelo usuário. Consulte o [relatório do instalador](../bin/setup_assistente_0214.validacao.json) e o [manifesto](../bin/setup_assistente_0214.manifest.json).

## Limites

A edição de membros usa rotação FK; não há IK para arrastar mãos/pés como alvos, translação de ossos, editor de curvas/trilhas, undo/redo, exclusão de quadros ou cadastro de tags. A seleção de outro avatar pela interface também continua pendente. O JSON grava a animação; o enquadramento da câmera é independente.

A validação de entrada dos anéis usa eventos reais do motor dentro do teste nativo; não equivale a homologação manual com todos os dispositivos de mouse. A automação externa não encontrou uma janela alvo utilizável neste ambiente. A validação do instalador usa `--no-ui`, mantendo o teste nativo do próprio editor. Hardware físico, microfone/STT real, Kinect, câmera, provedores de IA com credenciais reais e Office não foram homologados nesta suíte.

Os fontes estavam modificados localmente em relação ao commit de base registrado nos relatórios; os hashes identificam os binários e os recursos verificados. O instalador anterior à revisão CAD foi preservado em `build/installer-0214-before-cad`.
