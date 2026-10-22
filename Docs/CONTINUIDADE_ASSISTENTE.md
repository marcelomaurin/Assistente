# Continuidade do projeto Assistente

Atualizado em 22/10/2026.

## Arquitetura e fluxo atual

A tela de Configurações é a fonte de verdade: configurações salvas →
`TSetMain` → tela principal → componentes. Texto digitado e fala reconhecida
entram em `ProcessarEntrada`, compartilhando agente e `TAIAgentMemoryMap`.
O histórico permanece em `conversation-history.json` ao lado do executável.

O professor 3D já está integrado à janela Lazarus por `TProfessorView`/Castle,
com catálogo em `AVATARES`, seleção de perfil, zoom e comandos de gesto na
resposta da IA. Não reconstruir essa integração nem a tela de configurações.
Somente a thread LCL modifica o renderer. Os dez modelos agora incluem
o corpo completo sob roupas/calçados separados. O recorte antigo da pele em
cabeça/pescoço/mãos foi removido para corrigir braços ausentes nas mangas curtas.
`check_avatar_body.py` verifica topologia e conexão de todos os membros;
`run_body_render_checks.py` captura poses vestidas e uma cópia adulta neutra
sem roupa em `build`, sem alterar os perfis vestidos do aplicativo.

O áudio usa os componentes CHATGPT existentes, com as unidades de voz fixadas
em `vendor/chatgpt-voice` antes da biblioteca externa:

`microfone → TProfessorListener/TAIContinuousListener/VAD → WAV →
TVoiceInputBridge/STT → ProcessarEntrada → agente/memória → resposta →
TReceptionJob/TTS → avatar e áudio`

Com `ContinuousListening` habilitado, a escuta começa automaticamente em
`FormShow`. Não adicionar botão de captura manual nem atalho F9. A entrada
Android existente chega pelo receptor TCP e usa o mesmo `ProcessarEntrada`;
não implementa identificação de locutor nem sincronização labial.
O polling do receptor usa `WinSock2.select` no Windows; as funções `fpSelect`
exigem `BaseUnix` no outro caminho. A compilação Windows do código anterior
falhava por utilizar somente as funções Unix sem importar essas unidades.
`tests/remote_stt_tests.lpr` exercita entrega UTF-8 na thread principal,
rejeição por tamanho, recuperação e encerramento com cliente silencioso.

## Ciclo de fala e avatar

O microfone fica pausado durante STT, agente, preparação e reprodução de voz.
O timer LCL acompanha o job, aplica e confirma os comandos do avatar e retoma
a escuta apenas depois da conclusão, falha ou cancelamento do job.

No TTS remoto, `TReceptionJob` desativa `AutoPlay` e o cache interno do
sintetizador: o job precisa controlar o início do áudio e ser dono do arquivo
temporário solicitado. Os padrões anteriores iniciavam áudio antes do gesto
e direcionavam a saída ao cache, deixando o caminho esperado pelo job ausente.

`TAIAudioPlayer` agora consulta o estado real do dispositivo MCI no Windows,
com identificador próprio por instância. O job aguarda `Playing=False`, sem
estimar duração pelo tamanho do WAV. Cancelar interrompe a espera e fecha o
player. `PlaybackActive` controla o estado de fala do avatar. A geração remota
ainda pode aguardar o timeout do provedor; SAPI síncrono ainda pode demorar até
terminar o trecho corrente.

`ASSISTENTE_CONFIG_DIR` também isola os temporários e traces de recepção em
`reception/`. Sem a variável, permanece o diretório de dados anterior. Isso
permite regressões locais sem utilizar a configuração ou cache do usuário.

## Compilação e regressão

Use `scripts/build_professor.ps1`; o executável fica em
`build/professor/assistente.exe`, acompanhado de `AVATARES`. Não atualizar
automaticamente os binários antigos rastreados em `src`.

As regressões de TTS remoto estão em `tests/professor_remote_speech_tests.lpr`,
`tests/professor_audio_smoke.lpr` e `tests/run_remote_speech_checks.py`.
O runner fornece HTTP local, chave fictícia e WAV de silêncio com metadados,
verificando término, comandos, cancelamento, falhas e limpeza de arquivos.
O smoke LCL verifica preparação/fala do renderer real, recuperação dos
controles e Esc. Requer saída de áudio Windows e OpenGL; não usa captura,
câmera ou serviço remoto pago. Veja comandos e limites em
[professor-virtual-3d.md](professor-virtual-3d.md).

Em 22/10/2026 passaram a compilação i386-win32 do aplicativo e as regressões
listadas no guia: assets/movimento dos dez perfis, comandos/estados/catálogo,
gestos e interface LCL, voz remota local (worker e janela) e receptor TCP local.
São testes de software com WAV silencioso, sem credenciais ou captura física.

## Articulação dos modelos v4

Mandíbula, cadeias faciais, dedos e olhos agora são animados por esqueleto.
O loader Castle fixado ignora morph targets: os três targets originais ficam
somente como referência, com pesos de animação zero. A córnea preserva o alfa
para deixar íris e pupilas visíveis. A malha corporal e o suporte de ombro
continuam completos. Veja a regressão numérica em `check_avatar_motion.py` e
a comparação nativa independente de cabeça/braços em
`run_articulation_render_checks.py` / `professor_articulation_smoke.lpr`.
Não há músculos físicos nem alinhamento fonético da boca ou rastreamento de
olhar por câmera. O instalador 0.120 foi reempacotado com os modelos v4;
o manifesto identifica o commit de origem e os hashes do pacote atual.

## Pendências

- [ ] Validar conversa completa com provedor configurado e credenciais reais,
  incluindo memória entre perguntas por teclado e por voz.
- [ ] Validar microfone/VAD/STT físico: pausas naturais, retomada após TTS,
  falha/cancelamento e ausência de reconhecimento da própria voz do Assistente.
- [ ] Calibrar thresholds e validar filtros de ruído com microfone real;
  não mascarar falhas alterando números arbitrariamente.
- [ ] Validar SAPI com voz audível e a latência de encerramento durante fala.
- [ ] Validar câmera e Kinect físicos simultâneos, desconexão e recuperação.
- [ ] Implementar e validar identificação/aceitação de locutor no Android
  conforme a política documentada em `ASSINATURA_VOCAL_ANDROID.md`.
- [ ] Validar build Win64; o caminho verificado segue sendo i386-win32.
- [ ] Depois da validação física do áudio, continuar RAG e demais módulos,
  mantendo o `main` simples.

Ao concluir uma pendência, apague o item; não mantenha tarefas marcadas como
concluídas. Registre novos problemas e nunca declare testes que não executou.
