# Dependências de voz do Assistente

Fontes originais de https://github.com/marcelomaurin/CHATGPT
Commit: `838d24158dab7fa19df0f565c83b000da77d3095` (pacote/AI Voice).

Esta cópia fixa as unidades requeridas pelo Assistente que ainda não estão
na branch main da biblioteca local. Evita alterar o checkout compartilhado
de CHATGPT ou remover escuta contínua, supressão de eco e barge-in.
O compilador usa estas unidades antes da biblioteca externa.
Os demais componentes continuam vindo de ../../CHATGPT.

Adaptações locais para o Professor 3D: `aicontinuouslistener.pas` aceita
`DeviceIndex` (padrão -1 = WAVE_MAPPER), informa falha real de `waveInOpen`
e encerra a thread suspensa quando a construção da captura falha.
`aiaudioplayback.pas` também tem adaptação local: no Windows, WAV/MP3
usam dispositivo MCI próprio por instância, e a leitura de `Playing` consulta
o estado real e libera o dispositivo ao terminar. `OnPlaybackStop` é entregue
uma vez, na consulta que detecta o término ou em `Stop`; não há timer interno.
Os consumidores devem consultar `Playing` para observar o fim natural.
No Linux, a consulta acompanha o processo do player; esse caminho não foi
validado nesta alteração. A biblioteca externa CHATGPT permanece intacta.

A entrega de eventos à LCL é feita por `src/professor_listener.pas`, sem
alterar a biblioteca CHATGPT compartilhada.


## Controle de apresentação PVA

O adaptador local acrescenta TAIAudioPlayer.SetPaused e TAIVoiceSynthesizer.SetPaused/LocalSpeaking. O worker consulta a reprodução real e aplica pausa/retomada no próprio thread de áudio. A fila continua com confirmação da interface; as tags de mídia/articulação são habilitadas somente para PVA validado. SAPI é iniciado de forma assíncrona para permitir cancelamento e acompanhamento do término. Testes específicos: presentation_speech_tests.lpr e run_presentation_native.py.
