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
A entrega de eventos à LCL é feita por `src/professor_listener.pas`, sem
alterar a biblioteca CHATGPT compartilhada.
