# Assistente
Assistente de IA , criado para responder perguntas da FATEC

## Documentação e integração

Consulte o [índice de documentação](Docs/README.md), o
[manual do usuário](Docs/ManualUsuario/README.md), o
[projeto e funcionalidades](Docs/Projeto/README.md), o
[SDK por DLL](Docs/DLL/README.md) e o
[protocolo socket autenticado](Docs/Socket/README.md).

As fontes atuais oferecem API JSON v1 com token e lista de IPs permitidos,
além de DLLs cliente Win32/Win64 em `bin/integration`. Requerem o aplicativo
compilado dessas fontes e a opção Integração externa habilitada.
O instalador histórico 0.120 abaixo é anterior à API e não inclui esse servidor.

## Instalação Windows

Versão atual: [setup_assistente_0130.exe](bin/setup_assistente_0130.exe).
Inclui o aplicativo Win32 Release atualizado e os 11 avatares, com o Zé Gotinha
refeito em 3D a partir das referências: cabeça em gota, corpo arredondado,
emblema SUS e animações de fala, piscadas, olhar e gestos.
A instalação padrão é por usuário, em `%LOCALAPPDATA%\Programs\Assistente`.
Veja [instalação e verificação da versão 0.130](Docs/INSTALACAO_0130.md).
Os hashes estão no [manifesto](bin/setup_assistente_0130.manifest.json), e os
resultados dos testes no [relatório](bin/setup_assistente_0130.validacao.json).
A versão [0.120](Docs/INSTALACAO_0120.md) permanece disponível como histórico.

## Professor Virtual 3D

Avatar 3D nativo no formulário Lazarus, com dez perfis selecionáveis e
animações de repouso, escuta, pensamento, fala, aceno e caminhada.
Inclua novos `.glb`/`.gltf` na pasta **AVATARES** e atualize a lista pelo ↻.
A roda do mouse aproxima/afasta; duplo clique reenquadra.
Os modelos v4 usam anatomia contínua, esqueleto com pesos, texturas de pele e
tecido e expressões faciais. O corpo é completo sob a roupa: braços, tronco,
pernas e pés não dependem do vestuário para existir. A IA pode dirigir gestos no texto com `[sorriso]`,
`[aplausos]`, `[levantar mao direita]` e `[abaixar mao direita]`.
A versão v4 articula mandíbula, lábios, pálpebras, olhos e dedos por esqueleto,
compatível com o motor nativo. O instalador 0.120 foi atualizado com esses
modelos; consulte o SHA-256 do manifesto para identificar o pacote atual.
As tags não são pronunciadas. Veja [comandos e sincronização](Docs/avatar-comandos-ia.md).
Veja [arquitetura, modelos, instalação, build e limites](Docs/professor-virtual-3d.md).
O build atualizado fica em `build/professor/assistente.exe`; os executáveis
antigos presentes no repositório não são atualizados automaticamente.


## Vídeo local: Kinect e câmeras

Em Configurações → Vídeo, use **Habilitar Kinect** e **Habilitar câmera**.
As opções são independentes: nenhum, apenas Kinect, apenas câmera ou ambos.
Cada dispositivo tem sua própria lista. Atualizar dispositivos enumera hardware
local; Testar dispositivo verifica os habilitados e mostra preview RGB da câmera.
Não existe servidor, IP ou porta de captura de vídeo.

O Kinect v1 / Xbox 360 utiliza o SDK local e oferece profundidade, skeleton,
gestos, distância e apontamento. A câmera fornece somente RGB. As opções de
Kinect ficam habilitadas quando Kinect está marcado, inclusive com câmera ativa.
Desmarcar Kinect preserva seus ajustes e desativa os seus recursos.

Ao salvar, a aplicação libera as capturas anteriores e inicia os dispositivos
habilitados. A falha de um não impede a tentativa de inicializar o outro.
Cancelar fecha o teste e retoma a configuração anterior.

`VISION_SOURCE` aceita `none`, `kinect`, `webcam` e `both`. Os valores anteriores
continuam válidos, assim como a migração de `KINECT_ENABLED`. O índice do Kinect
e o nome da câmera são preservados. Novas configurações começam desabilitadas.

As câmeras usam drivers VFW do Windows: dispositivos disponíveis apenas por
DirectShow/Media Foundation podem não aparecer. As câmeras aparecem com índice e nome (por exemplo, `0 - USB Camera` e
`3 - USB Camera`), permitindo distinguir nomes iguais. A escolha é persistida.
Configurações antigas com apenas o nome são restauradas se não houver ambiguidade.
Os índices VFW e Kinect não são identificadores físicos estáveis: após mudanças
de portas/drivers, confirme a seleção pelo teste/preview.

Com vários equipamentos, selecione um Kinect e uma câmera nas respectivas listas.
Sem escolha salva válida, não se abre automaticamente o primeiro equipamento.
Um único equipamento disponível pode ser selecionado automaticamente. Cada lista
controla um equipamento daquele tipo; habilitar ambos permite Kinect + câmera.

### Validação

Execute `tests/run_vision_checks.ps1` para validar o formulário e as quatro
combinações. Use `-Hardware` para incluir captura real com exatamente uma câmera.
O teste anterior de câmera capturou RGB de 640×480.

A compilação completa usa as dependências de voz fixadas e adaptadas em
`vendor/chatgpt-voice` (origem, commit e adaptações documentados nessa pasta),
preservando a biblioteca CHATGPT externa. Para a versão com professor 3D, use
`scripts/build_professor.ps1` conforme o guia acima. O executável atualizado é
`build/professor/assistente.exe`, acompanhado de `AVATARES`.
Feche versões antigas antes de abrir esse arquivo; instalações e executáveis
antigos não são atualizados automaticamente. A configuração atual contém a aba
Vídeo local, sem servidor de captura. Os testes locais de TTS remoto e avatar
estão documentados em [professor-virtual-3d.md](Docs/professor-virtual-3d.md).

Com Kinect físico disponível, validar ambos ativos, desligamento independente,
troca de dispositivos e recuperação quando um dispositivo está ausente.
Os testes isolados não comprovam captura simultânea com Kinect físico.


## Editor de Apresentações PVA

Editor Lazarus independente, pacote único com roteiro e mídias, geração de gestos por IA e execução no Assistente com pausa/retomada.

Consulte o [manual do editor](Docs/editor-apresentacoes.md), o [catálogo de tags](Docs/tags-apresentacoes.md), o [formato PVA](Docs/formato-pva.md) e o [status de conclusão](Docs/plano-conclusao-editor-apresentacoes.md).
