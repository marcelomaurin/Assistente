# Assistente
Assistente de IA , criado para responder perguntas da FATEC


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

A compilação completa usa as dependências de voz originais fixadas em
`vendor/chatgpt-voice` (origem e commit documentados nessa pasta), preservando a
biblioteca CHATGPT externa. Compile com `C:\lazarus\lazbuild.exe --build-all
src\assistente.lpi`. O executável atualizado é `src/assistente.exe`.
Feche versões antigas antes de abrir esse arquivo; instalações antigas não são
atualizadas automaticamente. A configuração atual contém a aba Vídeo, sem servidor.

Com Kinect físico disponível, validar ambos ativos, desligamento independente,
troca de dispositivos e recuperação quando um dispositivo está ausente.
Os testes isolados não comprovam captura simultânea com Kinect físico.
