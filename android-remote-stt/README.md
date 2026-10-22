# Android Remote STT — protótipo inicial

Objetivo: microfone conectado ao Android -> reconhecimento nativo Android -> texto UTF-8 via TCP/Wi-Fi -> Assistente Lazarus. O áudio não sai do celular.

## Contrato de comunicação v0
- TCP porta 18765 no computador (configurável).
- Uma conexão por frase; uma linha UTF-8 terminada em LF; o receptor fecha a conexão.
- Somente resultados finais do SpeechRecognizer, sem parciais.
- Protocolo experimental para LAN confiável. **Não expor à internet**: ainda não há autenticação nem criptografia.
- O receptor Lazarus deve validar tamanho (ex.: 4096 bytes), rejeitar caracteres de controle e encaminhar ao ProcessarEntrada na thread principal LCL; nunca chamar a UI diretamente da thread de socket.

## Android
O arquivo `RemoteSpeechService.kt` é o núcleo do serviço, **não é ainda um APK compilável**. Faltam projeto Gradle, Activity de configuração (IP/porta/iniciar/parar), manifesto, permissões RECORD_AUDIO/INTERNET/FOREGROUND_SERVICE/FOREGROUND_SERVICE_MICROPHONE, notificação e testes em dispositivo.

Em Android recente, o usuário deve iniciar o serviço com o aplicativo visível e conceder permissão de microfone. O serviço foreground pode continuar com tela apagada, mas reconhecimento contínuo não é garantido: o SpeechRecognizer pode parar ou falhar dependendo do aparelho e do provedor. Validar o microfone externo selecionado pelo Android e política de bateria do fabricante.

## Receptor Lazarus

`src/remote_stt_server.pas` recebe o texto TCP e entrega o callback por
`TThread.Synchronize` à thread principal. `RemoteVoiceText` usa a mesma
`ProcessarEntrada` do teclado e da transcrição local, respeitando o estado
ocupado da conversa. O polling usa WinSock2 no Windows e BaseUnix no caminho
Unix. Em 22/10/2026 o aplicativo i386-win32 compilou e
`tests/remote_stt_tests.lpr` passou com conexões locais: UTF-8, thread principal,
rejeição por tamanho, recuperação e encerramento com cliente silencioso.
Isso não valida o serviço Android nem a política de locutor.

## Próximas etapas
1. Criar Activity e Gradle, permissões e fluxo de inicialização.
2. Acrescentar opção de entrada Android nas configurações, porta e token de pareamento.
3. Implementar autenticação e proteção contra duplicatas/reenvios; testar rede, tela apagada, reconexão e frases longas.
4. Compilar APK e executar testes reais no Android e no Lazarus.

Não foram executados compilação de APK nem testes com aparelho Android.
