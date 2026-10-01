# Revisão técnica — 01/10/2026

Base analisada: `3aa0cf21d3a58bef79d1c3998ad3d7d1bf5e3dce`.
Linguagem preservada: Object Pascal, Lazarus/LCL e Free Pascal.
Objetivo: atendimento da FATEC por texto e voz, com memória e documentos locais.

## Correções implementadas

- Configurações: o formulário existente voltou a carregar/salvar os valores por
  `config_binding`, sem duplicar controles na tela principal. Novos campos de voz
  são persistidos; configurações antigas recebem valores padrão antes da leitura.
- Áudio: a unidade de escuta incompatível foi substituída pela versão compatível
  com `TAIAudioInput`. O final de uma fala respeita a pausa solicitada pelo consumidor.
- O microfone permanece pausado durante STT, resposta e TTS. Um temporizador recolhe
  o job concluído; falhas de STT também notificam conclusão e liberam a escuta.
- Reprodução remota usa estado real do dispositivo MCI, com cancelamento e limite
  de espera. Reprodução automática duplicada foi desabilitada. Frases são agrupadas
  para evitar uma chamada de síntese a cada oito palavras.
- Modelo, endpoint, provedor e voz remota são aplicados. A configuração não troca
  silenciosamente `gpt-4o-mini-tts` por `tts-1`.
- O gerenciador possui e aguarda seu worker antes de liberar os componentes;
  solicitações concorrentes são rejeitadas e exceções geram conclusão de falha.
- O atendimento usa RAG lexical BM25 em `.md`/`.txt`, com fontes, fragmentação UTF-8,
  até 2.000 fragmentos e quatro resultados. A pesquisa não percorre o diretório
  atual quando a pasta não foi configurada. Histórico enviado limitado a 12 turnos.
- O fluxo institucional faz uma única chamada ao modelo, com instruções em papel
  de sistema. Documentos e histórico são tratados como dados. O fluxo não executa
  subtarefas ou operações de dispositivos sugeridas pelo modelo. As classes antigas
  de planejamento continuam disponíveis para compatibilidade, mas não são usadas
  nesse caminho de atendimento.
- Credencial JARVIS embutida removida; tokens e senhas de banco usam o armazenamento
  protegido já presente no projeto (DPAPI no Windows, com limitações abaixo).
- Seleção de câmeras/Kinect não escolhe o primeiro dispositivo em situações ambíguas.
- Avatar estático utiliza `TImage` e o leitor GIF do Free Pascal, eliminando uma
  dependência não declarada de `GifAnim`.
- Compilação ganhou caminhos de unidades faltantes e script sem caminho fixo `D:`.

## Validação executada

- Compilação completa Windows x64, Lazarus instalado em `C:\lazarus`, FPC 3.2.2.
- `vision_check`: seleção, ausência e combinações de dispositivos simuladas.
- `reception_tests`: histórico isolado, persistência, PCM, RAG e criação do formulário.
- `app_checks`: configuração, tokens de teste, modelo preservado, fontes RAG,
  recuperação de STT inválido, bloqueio/liberação da entrada em falha TTS.
- `run_with_mock.py`: servidor HTTP temporário em loopback, respostas válidas e
  inválidas, cancelamento, atendimento fundamentado e uma chamada por turno.
  Nenhum serviço pago é usado nesses testes.
- A compilação ainda emite avisos, principalmente na biblioteca externa e código
  legado. Compilar não comprova funcionamento físico de áudio ou sensores.

## Limitações e próximos passos

1. **Substituir a chave JARVIS antiga no servidor**. Removê-la do código atual não
   remove sua exposição no histórico Git. Nenhuma rotação remota foi executada.
2. Testar voz ponta a ponta no equipamento final: pausas naturais, qualidade de
   transcrição, conclusão real do TTS, desligamento e ausência de autoescuta.
3. A biblioteca atual de captura utiliza o dispositivo padrão do sistema. O índice
   salvo/testado na tela ainda não é aplicado por `TAIAudioInput`. As propriedades
   de eco/correlação dessa versão não equivalem a cancelamento acústico real.
4. A tela de vídeo enumera/testa dispositivos. O `main` simplificado não conecta
   Kinect/câmera continuamente a um fluxo de percepção. Avatar 3D também não está
   integrado; o botão de teste antigo apenas apresenta uma mensagem.
5. RAG é lexical; não inclui embeddings semânticos, reranking ou indexação incremental.
   Publicar documentos institucionais revisados e avaliar respostas antes de adicionar
   busca híbrida. Não foram inventados horários, cursos ou contatos para preencher a base.
6. A memória é de uma sessão local/usuário do Windows, sem autenticação de visitantes.
   Não usar uma conversa compartilhada para armazenar dados pessoais de vários visitantes.
7. O helper de credenciais legado tem fallback de ofuscação fora de DPAPI. Uma revisão
   futura deve adotar armazenamento de credenciais do SO sem fallback fraco. Bibliotecas
   TLS antigas distribuídas no repositório também precisam de atualização e validação
   de certificados antes de uma distribuição de produção.
8. Realtime/WebRTC, busca híbrida e captura Media Foundation são evoluções possíveis,
   mas exigem integração e avaliação específicas. Não foram anunciadas como implementadas.

## Referências técnicas consultadas

- [OpenAI — síntese de voz](https://developers.openai.com/api/docs/guides/text-to-speech)
- [Microsoft — consulta do estado MCI](https://learn.microsoft.com/en-us/windows/win32/multimedia/status)
- [Free Pascal — WaitFor e sincronização](https://www.freepascal.org/~michael/docs-demo/docskimmer/classes/tthread.waitfor/)

As referências fundamentam as correções de integração. Modelos configuráveis foram
preservados, sem depender de um nome de modelo supostamente mais novo.
