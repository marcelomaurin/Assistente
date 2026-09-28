# Continuidade do projeto Assistente

Atualizado em 28/09/2026.

Este documento existe para que outro agente/bot consiga continuar o trabalho sem reconstruir decisões já tomadas.

## Diretrizes de arquitetura

A tela de Configurações existente é a fonte de verdade. Não duplicar configurações no `main` e não reconstruir a tela. O fluxo desejado é:

`configurações salvas -> TSetMain -> tela principal -> módulos/componentes`

O `main` deve permanecer simples. Texto digitado e fala reconhecida devem entrar no mesmo caminho de agente e memória.

Não adicionar botão de microfone nem atalho F9. Com `ContinuousListening` habilitado, a captura deve permanecer automática enquanto o Assistente estiver ativo.

## Fluxo atual

Fluxo de entrada por voz integrado:

`microfone -> TAIAudioInput -> TAIContinuousListener/VAD -> WAV -> TVoiceInputBridge -> STT -> ProcessarEntrada -> agente + TAIAgentMemoryMap -> resposta -> TTS`

A entrada digitada chama a mesma `ProcessarEntrada`, portanto texto e voz compartilham contexto, memória e agente.

## Implementações já realizadas

### Tela principal reconstruída

O `main` foi simplificado para usar `TSetMain`, `TAssistantManager` e `TJarvisAPIClient`, mantendo avatar estático e campo de texto. Não reintroduzir a antiga arquitetura altamente acoplada.

### Memória da conversa

`TAIAgentMemoryMap` armazena as falas do usuário e respostas. O histórico é salvo em `conversation-history.json`, recarregado na inicialização e incluído no contexto de novas solicitações.

Commit de referência: `12c6e09d4bf9b6221278f8fd408660c529663b53`.

### TTS

`TReceptionJob` com `rjSpeak` usa as configurações de voz do `TSetMain`. Commit de referência: `31425f23ad116bc976b3c56c9d571920b98fcf88`.

### Ponte STT

Arquivo `src/voice_input_bridge.pas`.

`TVoiceInputBridge` recebe um WAV finalizado, monta `TReceptionConfig` a partir de `TSetMain`, executa `TReceptionJob(rjTranscribe)` e devolve o texto em `OnText`. O bridge não captura microfone e não implementa VAD; essas responsabilidades pertencem ao pacote CHATGPT.

Commit: `23b49e70b0405357f8cb0f60aee7ff52809daa39`.

### Ponte conectada ao main

`VoiceText` encaminha o texto reconhecido para a mesma `ProcessarEntrada` usada pelo teclado.

Commit: `9d16d3d930b0de3ac4989a37b5cfbea69259aea1`.

### Escuta contínua integrada

O `main` passou a criar `TAIAudioInput` e `TAIContinuousListener`. Com `FSetMain.ContinuousListening`, inicia automaticamente a escuta em `FormShow`.

Configurações consumidas do `TSetMain`:
- `AudioSampleRate`
- `AudioChannels`
- `VoiceThreshold`
- `SilenceTimeoutMs`
- `MinSpeechMs`
- `MaxSpeechMs`
- `EchoSuppressionEnabled`
- `SelfAudioCorrelationThreshold`

`OnSpeechReady` pausa a escuta e envia o WAV ao `TVoiceInputBridge`. O texto transcrito entra no agente/memória pelo fluxo comum.

Commit: `b432da9187f7f1e77f452bca8283672113f2bb5c`.

O pacote CHATGPT correspondente contém `TAIContinuousListener` e a evolução de `TAIAudioInput`. Consulte também `docs/CONTINUIDADE_AUDIO_VAD.md` no repositório CHATGPT.

## Regra de microfone durante TTS

O Assistente não deve reconhecer a própria fala. A escuta precisa permanecer pausada enquanto o agente está processando e principalmente enquanto o TTS estiver reproduzindo. Deve ser retomada somente após confirmação real de término do TTS.

O código atual ainda não concluiu esse ciclo: cria `FSpeechJob`, mas falta acompanhar corretamente o término do job para chamar `RetomarEscuta`.

## Limitações e pontos a validar

- Nenhuma das alterações recentes de áudio foi considerada compilada/testada ainda.
- É necessário compilar primeiro o CHATGPT atualizado e depois o Assistente.
- O fluxo real de microfone/VAD/STT precisa ser testado de ponta a ponta.
- O backend de nível/VAD do CHATGPT está inicialmente focado em Windows/MCI; Linux/ALSA ainda é pendência no pacote.
- Calibrar thresholds somente após teste real; não mascarar falhas de captura aumentando/diminuindo números arbitrariamente.
- A tela de configurações deve permanecer intacta.

## Tarefas pendentes para o próximo agente

- [ ] Corrigir o ciclo TTS/microfone: observar término real de `FSpeechJob` e executar `RetomarEscuta` somente após o TTS terminar.
- [ ] Compilar o pacote CHATGPT atualizado no Lazarus/Free Pascal e corrigir erros encontrados sem remover a arquitetura de escuta contínua.
- [ ] Compilar o Assistente com o pacote atualizado.
- [ ] Testar: iniciar Assistente -> escuta automática -> começar fala -> pausa curta -> continuar fala -> silêncio final -> WAV -> STT -> texto -> agente -> resposta.
- [ ] Confirmar que nenhuma palavra é cortada nas pausas normais da fala.
- [ ] Confirmar que o Assistente não transcreve o próprio TTS.
- [ ] Calibrar `VoiceThreshold`, `SilenceTimeoutMs`, `MinSpeechMs` e `MaxSpeechMs` com microfone real.
- [ ] Integrar/validar filtros de ruído do pacote CHATGPT no caminho de áudio.
- [ ] Depois que o áudio estiver estável, retomar as próximas etapas do projeto (RAG e demais módulos) sem voltar a acoplar tudo ao `main`.

## Regra obrigatória de manutenção desta lista

**Quando uma tarefa acima for concluída, APAGUE a tarefa da lista. Não deixe item marcado como concluído.** Este documento deve mostrar para o próximo agente apenas o trabalho que continua pendente.

Se surgir uma nova pendência durante compilação/teste, acrescente-a. Não declarar compilação ou teste bem-sucedido sem realmente executá-lo.
