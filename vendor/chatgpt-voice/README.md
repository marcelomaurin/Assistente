# Dependências fixadas do Assistente

Origem: https://github.com/marcelomaurin/CHATGPT (licença nesta pasta).

- Unidades de voz originais: commit `838d24158dab7fa19df0f565c83b000da77d3095`.
- `aicontinuouslistener.pas`: `pacote/AI Input/AIAudio`, commit
  `4188adf07d027b8df479eb6bf6986a31278a19cb`, com correção local para respeitar
  `FPaused` após `OnSpeechReady` e não reabrir o microfone durante STT/TTS.
- `airetrieval.pas`: `pacote/AI RAG`, mesmo commit `4188adf...`, com interfaces
  CORBA sem contagem de referências. Os componentes são possuídos/liberados pelo
  chamador; isso evita a incompatibilidade QueryInterface const/constref do FPC
  3.2.2 x64 encontrado nesta compilação. Não misturar com consumidores COM dessas
  interfaces. A cópia inclui apenas esta mudança de diretiva.

As demais unidades vêm de `../../CHATGPT`, validado no commit
`4188adf07d027b8df479eb6bf6986a31278a19cb`. A biblioteca externa não foi alterada.
O listener atual não implementa cancelamento acústico real nem seleção de índice
de microfone; veja `docs/REVISAO_TECNICA.md`.
