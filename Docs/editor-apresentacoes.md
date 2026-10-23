# Editor de Apresentações

O editor Lazarus independente cria pacotes `.pva` para o Assistente. A implementação Windows inclui roteiro UTF-8, recursos, movimentos gerados pela IA, articulações e reprodução de imagem/vídeo e PowerPoint, com somente uma mídia visual ativa.

## Compilar e abrir

Requisitos: Windows 10/11, FPC 3.2.2 i386, Lazarus com LCL/SynEdit i386, dependência CHATGPT do projeto e Castle Engine conforme [guia do avatar](professor-virtual-3d.md). O editor e o utilitário PVA não dependem do renderer Castle; o Assistente depende dele.

```powershell
python scripts/build_presentations.py
build/presentations/presentation_editor.exe
```

O script usa `.deps/chatgpt-integration-baseline` ou a biblioteca irmã `../CHATGPT`. Castle pode ser indicado com `--castle` ou `CASTLE_ENGINE_PATH`. Em um checkout já compilado, também aceita as unidades Castle de `build/professor/units/i386-win32`. Para uma instalação limpa, prepare as dependências conforme o guia do avatar. Opções: `--compiler`, `--lazarus`, `--out`, `--target editor|assistant|tool|tests|all`.

O projeto de IDE é src/presentation_editor.lpi; use compilador i386 e as dependências preparadas. O editor pode ser compilado isoladamente com `--target editor`. Distribua `presentation_editor.exe` e as bibliotecas SSL já utilizadas pelo componente CHATGPT. A prévia requer o Assistente atualizado, seus avatares e suas dependências de voz. Os binários antigos e o instalador 0.130 não são substituídos automaticamente.

## Fluxo de uso

1. Escreva o texto do roteiro.
2. Posicione o cursor e use **Inserir mídia**. O editor copia o arquivo para seu espaço temporário e insere a tag naquela posição. A lista de recursos permite reinserir o mesmo arquivo com duplo clique.
3. Use **Fechar mídia**, **Próximo slide**, **Slide anterior** e **Ir ao slide** nos pontos desejados.
4. Use **Gerar movimentos IA** para inserir ou regenerar gestos. O texto fica bloqueado durante a requisição. **Cancelar IA** cancela o pedido; a aplicação pode aguardar o timeout de rede.
5. **Desfazer/Refazer** também funciona para a geração inteira da IA.
6. **Validar** verifica o roteiro, os arquivos e o pacote. **Salvar/Salvar como** produz o arquivo único `.pva`. **Abrir .pva** recupera o roteiro e os recursos.
7. Confira o caminho do executável atualizado e use **Prévia no Assistente**.

A configuração de IA é lida do arquivo `Setmain.cfg` existente em `ASSISTENTE_CONFIG_DIR`. Sem a variável, o editor procura `%LOCALAPPDATA%/assistente`. Reutiliza token, provedor, modelo e endpoint do Assistente, por meio de `TCHATGPT`; não salva credenciais no pacote e não modifica o arquivo de configuração.

A IA recebe a projeção do roteiro sem gestos anteriores. Sua resposta precisa conservar exatamente todos os demais caracteres: texto, espaços, quebras de linha, tags de mídia e suas posições. Resposta inválida, mídia deslocada ou texto reescrito é recusado sem aplicar alterações. O retorno é JSON com campo `script`.

## Executar

```powershell
build/presentations/assistente.exe --presentation caminho/apresentacao.pva
build/presentations/assistente.exe caminho/apresentacao.pva
build/presentations/assistente.exe --presentation-silent caminho/apresentacao.pva
```

Na janela do Assistente, **P** pausa/retoma e **Esc** cancela. A configuração **AutoSpeak** determina a fala; `--presentation-silent` força apresentação sem áudio. Esc também funciona durante a pausa. A captura do microfone fica pausada durante a reprodução.

O executor valida todo o pacote antes de extrair em uma pasta temporária exclusiva. As tags entram na mesma fila de confirmação dos gestos: a mídia muda na fronteira correspondente do roteiro, após o trecho anterior e antes do seguinte. As tags reconhecidas são removidas do TTS. Ao terminar, cancelar, falhar ou fechar o Assistente, a mídia é encerrada e os temporários são removidos.

Quando a síntese é remota, a espera pela rede acontece antes de disparar os eventos do próximo trecho. Uma síntese já em andamento pode aguardar seu timeout antes de o worker terminar; a mídia fecha imediatamente no cancelamento. Pausar congela áudio já iniciado, vídeo, renderização e a linha do tempo. A apresentação com fala requer SAPI ou voz remota; eSpeak é recusado nesse modo porque não oferece a mesma pausa controlada.

O movimento de mandíbula acompanha somente o estado de áudio efetivamente em reprodução, independentemente dos gestos. É uma animação genérica de fala; não há análise de fonemas/visemas.

## Mídias e dependências

- PNG, JPEG e BMP: janela nativa Lazarus.
- AVI, WMV e MP4: MCI do Windows, dentro da mesma janela. O codec do arquivo precisa estar disponível no Windows; uma extensão aceita não garante codec instalado. Falhas são exibidas e interrompem a apresentação.
- PPTX: Microsoft PowerPoint instalado, ativado e disponível na sessão interativa do usuário. A automação abre o arquivo em leitura e com macros desabilitadas, inicia no slide 1 e usa avanço manual comandado pelo roteiro. Imagens e vídeos usam a janela Lazarus; slides usam a janela nativa de apresentação do PowerPoint, controlada pelo Assistente. Não há conversão por LibreOffice nem renderer parcial de PPTX embutido.

Abrir outra mídia visual substitui e encerra a anterior. O som tem canal próprio, descrito abaixo. **Fechar mídia** encerra o visual e o som, é idempotente e não exige nome. Comandos de slides sem apresentação ativa ou fora dos limites causam erro explícito. O pacote não aceita executáveis, URLs, PPT/PPTM nem links simbólicos.

## Verificação

```powershell
python scripts/build_presentations.py --target tests
python tests/run_presentation_checks.py build/presentations/pva_tool.exe
python tests/run_presentation_native.py build/presentations AVATARES/professor/modelo.gltf
```

O teste nativo precisa de desktop Windows, saída de áudio e PowerPoint funcional. Para validar os outros caminhos em uma sessão sem Office, passe `--without-office`; o relatório identifica o teste de PowerPoint como ignorado. Dependências Python dos testes: `tests/presentation-requirements.txt`. Os provedores de IA e TTS dos testes são HTTP locais, sem credenciais reais; o WAV de teste contém silêncio.

Também execute os testes anteriores `professor_commands_tests.exe`, `professor_speech_commands_tests.exe` e `professor_state_tests.exe`. Há workflow manual `presentations.yml` para runner Windows preparado. Ele não instala Office nem configura suas credenciais.

## Evidência desta entrega — 23/10/2026

Compilados editor, utilitário e Assistente Win32; aprovados os testes do parser anterior, fila de fala/cancelamento, estados, UTF-8 inclusive em caminhos com espaços e acentos, SHA-256 e 22 ZIPs adversariais. Testes nativos verificaram imagens, AVI, substituição e fechamento de mídia, editor, inserção no cursor, desfazer/refazer, avatar, articulação, boca silenciosa, pausa/retomada e cancelamento. IA foi validada contra o componente real usando provedor local.

**PowerPoint validado na sessão do usuário:** abertura no slide 1, avanço, retorno, slide específico, recusa de slide fora dos limites e fechamento passaram com um PPTX real. Também passaram áudio WAV real com pausa/retomada e cancelamento durante pausa. O primeiro teste na conta isolada falhou por falta de sessão de logon; a validação completa foi executada fora desse isolamento, na sessão Windows do usuário.

Veja o [catálogo de tags](tags-apresentacoes.md), o [formato PVA](formato-pva.md) e o [plano com status](plano-conclusao-editor-apresentacoes.md).


O adaptador fecha somente o arquivo que abriu e preserva apresentações que já estavam no PowerPoint. Restaura a configuração de segurança de automação após abrir o PPTX. O comportamento de aplicação compartilhada segue o [modelo de automação do PowerPoint](https://learn.microsoft.com/en-us/previous-versions/office/troubleshoot/office-developer/use-visual-c-automate-run-program-instance); a abertura com macros desabilitadas segue [AutomationSecurity](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.application.automationsecurity).


## Vídeo/som em hh:mm:ss, avatar e voz

**Inserir mídia** e o duplo clique em recursos de áudio/vídeo perguntam pelo ponto inicial opcional em hh:mm:ss. Deixar vazio reproduz desde o começo. WAV, MP3 e WMA são importados e empacotados como os demais recursos; o codec continua sendo responsabilidade do Windows.

Use **Escolher avatar** para inserir a seleção pelo catálogo do Assistente escolhido, **Escolher voz** para inserir o nome da voz do provedor/SAPI e **Fechar som** para encerrar somente o canal de recurso sonoro. Os nomes e o início ficam no roteiro, são incluídos no PVA e preservados pela IA. O avatar/voz padrão da instalação não é gravado nem modificado por essas tags.

O canal de som pode acompanhar uma mídia visual. Se vídeo ou som ainda estiverem tocando depois da última fala, a apresentação aguarda seu término. P pausa/retoma e Esc encerra também esse período final. As tags e as regras de validação estão no [catálogo](tags-apresentacoes.md).

Os testes adicionais verificam posição real de AVI/WAV, limites de duração, som junto de imagem, encerramento independente, troca de avatar/restauração, conclusão do som final e o campo de voz nas requisições TTS locais. Voz SAPI inexistente é recusada antes de emitir áudio.
