# YouTube nas apresentações

No Editor de Apresentações, abra a aba **Mídia, slides e voz**, clique em
**YouTube** e cole o link do vídeo. A tag segue o padrão das outras mídias:

```text
[youtube=https://www.youtube.com/watch?v=M7lc1UVf-VE]
[fechar arquivo]
```

Também são aceitos `[youtube:https://youtu.be/M7lc1UVf-VE]` e a forma
`[youtube:{https://youtu.be/M7lc1UVf-VE}]`. As chaves são opcionais.
Links de vídeos comuns, links curtos, Shorts, lives e embeds são normalizados.
Para iniciar em um ponto, copie um link com `t=90`, `t=1m30s` ou `start=90`.

Ao chegar à tag, o Assistente mostra o player dentro de sua própria janela.
Clique em **Reproduzir vídeo**. O roteiro aguarda o término do vídeo ou o
botão **Continuar apresentação**, e então retoma a fala e as próximas tags.
**P** pausa/retoma; **Esc** cancela, inclusive com o foco no player.
`[fechar arquivo]` fecha o painel, como nas outras mídias.

O link permanece no `.pva`, sem baixar ou incluir o vídeo no pacote. A voz
não lê a tag nem o endereço. É necessário acesso à internet e o Microsoft
Edge WebView2 Runtime. O carregador é distribuído com o Assistente; em máquinas
sem o Runtime, instale-o pela [página oficial da Microsoft](https://developer.microsoft.com/microsoft-edge/webview2/).
Vídeos privados, removidos ou que proíbem incorporação exibem uma mensagem no
player; **Continuar apresentação** permite seguir o roteiro.

## Integração e testes

O player usa a API oficial do YouTube dentro de um WebView2 nativo. O HTML é
servido por um mapeamento HTTPS local do aplicativo, fornecendo a identidade
exigida pelo player. Pop-ups e navegações para fora do painel são bloqueados.
A implementação segue a [identificação de clientes do YouTube](https://developers.google.com/youtube/terms/required-minimum-functionality)
e o [mapeamento de conteúdo local no WebView2](https://learn.microsoft.com/microsoft-edge/webview2/concepts/working-with-local-content).

O SDK do carregador Microsoft é fixado por versão e SHA-256 em
`runtime/WebView2/1.0.4314.35/sdk-lock.json`; a licença acompanha a distribuição.
Os testes cobrem links inválidos, tags, PVA, inserção e desfazer no editor,
espera pelo vídeo, callbacks do WebView2, pausa, resize e destruição assíncrona.
`presentation_webview_tests --online` também verifica um stream real, sem som.
