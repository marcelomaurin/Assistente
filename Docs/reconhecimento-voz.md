# Reconhecimento de voz: Chrome e OpenAI

## Chrome sem chave

No Assistente, abra Config. > Entrada de Voz / Microfone, selecione **Chrome / Google (sem chave de API)** e ative a escuta contínua. Ao salvar, o Assistente abre uma janela do Google Chrome. Clique em **Iniciar escuta** e autorize o microfone. Mantenha essa janela aberta. O dispositivo de entrada é escolhido nas permissões do Chrome.

Requer Chrome desktop 135 ou superior para fornecer ao reconhecedor a trilha já filtrada. A janela não captura áudio antes do clique. O reconhecimento do navegador pode depender da internet e enviar áudio ao serviço do navegador. Não é uma API REST anônima do Google Cloud nem um serviço com disponibilidade garantida.

O componente reutilizável `TAIChromeSpeech` fica no pacote CHATGPT, unidade `aichromespeech`. `Start` abre uma ponte HTTP restrita a 127.0.0.1 em porta dinâmica; `OpenBrowser` abre o Chrome; `Poll` entrega eventos na thread principal. `SetPaused` invalida gravações anteriores; `Stop` fecha a ponte. Não se usa `TranscribeFile` para esse modo: o navegador captura o microfone. A sessão tem identificador aleatório, verifica Host/Origin e limita tamanho e tempo das requisições. O texto não é registrado pelo componente.

Durante a resposta do Assistente, o reconhecimento é interrompido e a trilha é silenciada. O botão Parar libera o microfone. Fechar a janela interrompe a escuta; para reabrir, pause e reative o botão de microfone no aplicativo.

## OpenAI

Selecione **OpenAI Whisper**. A captura nativa grava somente trechos de fala e faz a transcrição em segundo plano. Ordem de credenciais: `STT_TOKEN` específico, token configurado em IA/ChatGPT, e finalmente `OPENAI_API_KEY` no ambiente para uso independente do componente. `STT_MODEL` continua `whisper-1` e `STT_ENDPOINT` continua o endpoint de transcrição OpenAI, sem reaproveitar o endereço do chat. O idioma `pt-BR` é convertido para `pt` na requisição Whisper.

O componente `TAIVoiceRecognizer` agora aceita `ChatGPTToken` além de `OpenAIToken`; ambos não são serializados em formulários Lazarus. O token de síntese de voz não é usado como credencial de reconhecimento. A OpenAI tem cobrança própria; a escolha do Chrome não envia áudio à OpenAI.

## Filtro e silêncio

Nos dois modos, um passa-altas de 100 Hz e um passa-baixas de 7000 Hz preservam a faixa ampla da fala. Na captura nativa, o limite superior se ajusta abaixo de Nyquist para taxas menores, cada canal tem estado independente e o áudio filtrado é usado também no WAV de transcrição. No Chrome, Web Audio fornece a trilha filtrada ao reconhecedor e solicita redução de ruído/cancelamento de eco do navegador.

A análise de energia usa limiares distintos para início/fim e estima o ruído de fundo nos intervalos sem fala. A captura nativa exige confirmação de início, tempo mínimo de **voz efetiva** (não contando a pausa) e silêncio sustentado antes de concluir. Padrões existentes: 250 ms de fala mínima e 900 ms de silêncio; os valores de configuração do Assistente são aplicados ao Chrome também.

A filtragem reduz graves, agudos e acionamentos por silêncio. Sons que compartilham a faixa da voz ainda podem ser reconhecidos como fala; ajuste VoiceThreshold ao microfone/ambiente. Não se trata de isolamento perfeito de voz.

## Validação

Testes locais sem credenciais reais nem microfone: `chrome_speech_tests`, `voice_native_tests`, `run_chrome_page_checks.js` e `run_openai_stt_checks.py`. Cobrem UTF-8, sessão/origem, pausa, resultados antigos, encerramento, trilha filtrada, autorização negada, faixas de frequência, independência estéreo, duração mínima, silêncio e erros HTTP/JSON da OpenAI.

Ainda é necessária uma validação de fala real no Chrome, com autorização do microfone, e uma transcrição real OpenAI com credencial válida. Os testes automáticos não medem a precisão dos serviços na voz do usuário.

## Referências

- [Chrome Web Speech API](https://developer.chrome.com/blog/voice-driven-web-apps-introduction-to-the-web-speech-api)
- [Especificação Web Speech e trilha de áudio](https://webaudio.github.io/web-speech-api/)
- [Faixa ampla de fala, ITU G.722](https://www.itu.int/ITU-T/recommendations/rec.aspx?rec=11673)

## Integração da dependência

Os arquivos Chrome e `aispeechfilter.pas` foram implementados primeiro em `CHATGPT/pacote/AI Voice` e copiados ao vendor do Assistente. `chrome-speech-source.json` registra hashes para conferir igualdade. O reconhecedor foi adaptado nos dois locais. O listener nativo continua sendo o adaptador local do Assistente e preserva correções anteriores de captura. A revisão fixada em `.deps` foi preservada. Alterações locais preexistentes dos dois projetos foram mantidas.

### Resultado desta implementação (24/10/2026)

Os programas foram recompilados em `build/voice-chrome-openai`. As 11 verificações selecionadas passaram; relatório completo em `build/voice-chrome-openai/validation-report/result.json`. Os testes diretos de Chrome/OpenAI no checkout CHATGPT também passaram.

A versão 0.215 inclui estes recursos. A precisão com microfone e provedores reais continua pendente conforme descrito acima.
