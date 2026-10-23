# Catálogo de tags de apresentação

As tags abaixo compartilham o parser com os 40 comandos de avatar existentes, descritos em [avatar-comandos-ia.md](avatar-comandos-ia.md). Eles continuam disponíveis. Código entre crases, escapes e rótulos de links/imagens Markdown conservam o tratamento literal do parser anterior.

| Tag | Efeito |
| --- | --- |
| `[executar arquivo=assets/figura.png]` | Abre a mídia e encerra a anterior |
| `[abrir arquivo=assets/figura.png]` | Mesmo efeito |
| `[fechar arquivo]` | Fecha a mídia ativa, sem argumento |
| `[proximo slide]` | Avança um slide da apresentação ativa |
| `[slide anterior]` | Retorna um slide |
| `[ir para slide=3]` | Vai a um slide numerado a partir de 1 |
| `[articulacao=head,y,20,1000,suave]` | Interpola a articulação durante 1000 ms |

O primeiro slide de um PPTX é sempre 1. Navegação requer PPTX ativo e número dentro da quantidade real de slides. Abrir imagem/vídeo encerra o PowerPoint ativo.

As tags não são pronunciadas. Os eventos executam antes do trecho de fala seguinte, depois do anterior. No modo sem fala, o relógio usa a duração estimada dos segmentos. Tags de mídia e articulação só são executadas em uma apresentação PVA validada; o chat não pode abrir arquivos por conta própria.

## Articulações

Sintaxe exata:

```text
[articulacao=osso,eixo,angulo,duracao,interpolacao]
```

- `osso`: nome sensível a maiúsculas do rig incluído.
- `eixo`: `x`, `y` ou `z`, no espaço local do osso.
- `angulo`: graus, com ponto decimal, relativo à pose inicial capturada para a articulação.
- `duracao`: inteiro de 50 a 10000 milissegundos.
- `interpolacao`: `linear` ou `suave` (smoothstep).

| Ossos aceitos | Limite absoluto |
| --- | --- |
| `head`, `neck01`, `neck02`, `neck03` | 25° |
| `spine01` até `spine05` | 15° |
| `upperarm01.L/R`, `lowerarm01.L/R` | 90° |
| `wrist.L/R` | 35° |

`L/R` significa os nomes completos, por exemplo `upperarm01.L` ou `upperarm01.R`. O modelo precisa conter o osso solicitado; ausência é erro explícito. Cada osso mantém um único eixo/ângulo alvo por vez. O movimento permanece na pose alvo; use ângulo 0 para retornar. Encerrar/cancelar a apresentação limpa as poses. Os limites conservadores são a política do adaptador para os rigs incluídos, não uma medição automática de limites anatômicos de modelos externos.

Mandíbula, lábios, língua e demais ossos não listados são recusados. A boca é dirigida pela reprodução de áudio e não por essas tags.

## Exemplo

```text
[sorriso] Olá!
[executar arquivo=assets/figura.png] Aqui está a imagem.
[articulacao=head,y,15,800,suave] Vamos observar este detalhe.
[articulacao=head,y,0,800,suave]
[executar arquivo=assets/aula.pptx] Primeiro slide.
[proximo slide] Segundo slide.
[ir para slide=1] Voltamos ao começo.
[fechar arquivo] Obrigado!
```

Não use marcações inválidas de mídia/articulação como texto falado: a validação do roteiro as recusa. Os exemplos pressupõem os recursos correspondentes dentro do pacote.
