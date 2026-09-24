# Assistente
Assistente de IA , criado para responder perguntas da FATEC


## Visão local: Kinect e webcam

Em Configurações → Visão, selecione uma única fonte: Nenhuma, Kinect v1 ou
Webcam. Atualizar dispositivos refaz a descoberta local; Testar dispositivo
abre o hardware selecionado. A webcam exibe um preview RGB. Ao fechar a
configuração, a captura de teste é liberada e a fonte configurada é retomada.
Salvar aplica a troca sem reiniciar o Assistente; Cancelar retoma a fonte anterior.

* Kinect v1 / Xbox 360: conectado diretamente ao computador, utiliza o SDK
  local (`kbKinectSDK10`). Não necessita servidor de visão, IP ou porta.
  Permite profundidade, skeleton, gestos, distância e apontamento.
  Sem hardware, informa “Kinect não detectado”, sem simulação automática.
* Webcam: captura RGB local pela biblioteca CHATGPT. Nesta primeira etapa,
  enumeração e captura usam os mesmos drivers VFW do Windows. Câmeras
  disponíveis apenas por DirectShow/Media Foundation podem não aparecer.
  A seleção é persistida pelo nome do driver. Drivers com nomes idênticos
  não são selecionados automaticamente. Um backend DirectShow completo com
  identificadores estáveis ainda é necessário para cobertura geral de webcams.
* Nenhuma: não inicializa sensores. Texto e voz continuam independentes da visão.

Webcam não emula Kinect: não produz skeleton, profundidade, distância métrica,
gestos ou apontamento Kinect. Esses ajustes ficam desabilitados na tela e seus
valores são preservados para quando Kinect voltar a ser selecionado.

A configuração grava `VISION_SOURCE` (`none`, `kinect`, `webcam`),
`KINECT_DEVICE_INDEX` e `CAMERA_DEVICE`. Arquivos antigos com
`KINECT_ENABLED:1` ou `KINECT_ENABLED:true` migram para Kinect quando não há
`VISION_SOURCE`. Novas configurações começam com visão desativada. Chaves antigas
do servidor visual não são lidas nem gravadas. A porta de reconhecimento de voz
é uma configuração independente.

### Validação da primeira etapa

`tests/vision_check.lpr` verifica carregamento do formulário, seleção de fonte,
capacidades, bloqueio de opções Kinect e preservação de valores.
`tests/webcam_check.lpr` faz captura real quando há exatamente uma câmera:
abre o dispositivo, obtém um bitmap RGB e encerra a captura.
Execute `tests/run_vision_checks.ps1`; use `-Hardware` para incluir captura real.

Na máquina de desenvolvimento, o teste isolado do formulário passou e a webcam
forneceu um quadro RGB de 640×480. A compilação completa permanece bloqueada por
`aivoicecredentialstore`, unidade previamente referenciada e ausente da cópia
local de CHATGPT. Kinect físico e troca de fontes no aplicativo completo ainda
precisam de validação com as dependências completas.

Roteiro de teste no aplicativo completo:

1. Sem câmeras: selecionar Nenhuma e confirmar texto/voz; Kinect selecionado
   deve informar ausência, sem simular presença.
2. Somente webcam: atualizar, selecionar e testar preview; opções Kinect inativas.
3. Somente Kinect: enumerar, abrir, confirmar tracking real e erro real do SDK.
4. Ambos: alternar Kinect → Webcam → Nenhuma; confirmar liberação do dispositivo
   anterior, ausência de eventos Kinect na webcam e preservação dos ajustes.
5. Reabrir configuração, cancelar teste e reiniciar: confirmar fonte persistida,
   seleção do dispositivo e migração de configuração antiga.

Esta etapa implementa a seleção e separação das fontes. Fallback automático
Kinect → webcam e a generalização completa dos eventos semânticos ficam para
a etapa seguinte.
