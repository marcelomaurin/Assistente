# Assinatura vocal — integração Assistente / Android

## O que foi implementado
- `android-remote-stt/app/src/main/java/br/com/maurinsoft/assistente/SpeakerSessionGate.kt` contém uma política de sessão: primeira frase abre sessão, resultado `SAME` aceita, `DIFFERENT` rejeita e `INCONCLUSIVE` aceita.
- `RemoteSpeechService.kt` usa o `SpeechRecognizer` do Android para produzir texto em português e transmiti-lo por TCP ao computador.
- `src/remote_stt_server.pas` recebe linhas de texto; `src/main.pas` encaminha a entrada para `ProcessarEntrada`.
- O pacote Pascal compartilhável de política de locutor foi iniciado em `marcelomaurin/CHATGPT`, `pacote/AI Input/AIAudio/aispeakersignature.pas` (PR #19).

## Limitação importante
**Ainda não existe identificação biométrica funcional neste aplicativo.**
O serviço Android não extrai embeddings de áudio, não invoca `SpeakerSessionGate` e não bloqueia outras vozes. `SpeechRecognizer` não fornece PCM bruto de modo confiável. A classe atual representa somente a política de aceitação, não uma verificação real de identidade.

## Regra de negócio obrigatória
1. A primeira fala com assinatura válida estabelece referência temporária, sem cadastro prévio.
2. Comparar cada fala com a primeira referência, não com a fala imediatamente anterior.
3. Mesma pessoa: encaminhar texto ao Assistente.
4. Pessoa diferente com confiança suficiente: descartar a fala.
5. Resultado inconclusivo: **sempre encaminhar**; não atualizar a assinatura de referência.
6. Encerrar sessão por comando explícito ou inatividade configurável (sugestão inicial: 30 s); após encerrar, próxima pessoa pode estabelecer referência.
7. Não guardar áudio nem assinatura após encerrar, salvo opção explícita e consentida.

## O que falta implementar e validar
- [ ] Extrator real de embeddings de locutor com modelo compatível Android e desktop, licenças e métricas.
- [ ] Captura de áudio PCM via `AudioRecord` e STT compatível com o mesmo fluxo, sem presumir que `SpeechRecognizer` compartilhe PCM.
- [ ] Conectar decisão biométrica ao envio TCP: **somente** bloquear `DIFFERENT` com confiança calibrada.
- [ ] Implementar fim de sessão por comando/inatividade e descarte da assinatura temporária.
- [ ] Validar equivalência entre componente Pascal do pacote CHATGPT e lógica Android.
- [ ] Criar projeto Android compilável (Gradle, Activity, Manifest e permissões).
- [ ] Testar com amostras de vozes licenciadas: locutor igual/diferente, fala curta, ruído, microfone externo e tela apagada.
- [ ] Calibrar limiares com medidas de falsas aceitações, falsas rejeições e inconclusivos.
- [ ] Testar compilação do Lazarus e do APK; proteger transporte por autenticação/criptografia.

**Status:** protótipo, não homologado. Não declarar reconhecimento de locutor concluído.
