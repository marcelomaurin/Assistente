# Catálogo de tags de apresentação

As tags abaixo compartilham o parser com os 40 comandos de avatar existentes, descritos em [avatar-comandos-ia.md](avatar-comandos-ia.md). Eles continuam disponíveis. Código entre crases, escapes e rótulos de links/imagens Markdown conservam o tratamento literal do parser anterior.

| Tag | Efeito |
| --- | --- |
| `[executar arquivo=assets/figura.png]` | Abre a mídia e encerra a anterior |
| `[abrir arquivo=assets/figura.png]` | Mesmo efeito |
| `[fechar arquivo]` | Fecha a mídia visual e o som ativo, sem argumento |
| `[fechar som]` | Fecha somente o arquivo de áudio, preservando a imagem/vídeo/slide |
| `[executar arquivo=assets/filme.mp4\|inicio=00:01:30]` | Inicia o vídeo no ponto indicado |
| `[executar arquivo=assets/som.wav\|inicio=00:00:10]` | Inicia o som no ponto indicado |
| `[avatar=engenheiro]` | Seleciona o avatar instalado pelo ID |
| `[voz=nova]` | Seleciona a voz para as próximas falas |
| `[voz=padrao]` | Restaura a voz original da apresentação |
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


## Início de vídeo e som

O sufixo opcional é **|inicio=hh:mm:ss**, com exatamente dois dígitos em cada campo. Horas: 00–99; minutos/segundos: 00–59. Sem o sufixo, o recurso começa em 00:00:00. Um ponto igual ou posterior ao fim real do arquivo é recusado antes de reproduzir. Imagens e PPTX não aceitam início temporal.

Áudio aceita WAV, MP3 e WMA, conforme os codecs do Windows. Há uma única mídia visual e um único som de recurso ativos. Assim, uma imagem ou slide pode ficar visível enquanto um som toca. Abrir outro som substitui o anterior, sem fechar a imagem. Abrir outra mídia visual preserva o som. O áudio do vídeo e a fala TTS são independentes desse canal.

P pausa/retoma todos os canais. Esc fecha tudo. Ao chegar ao fim do roteiro, o executor aguarda vídeo/som ainda em reprodução; uma imagem estática ou PPTX não prolonga a apresentação. Som de recurso não movimenta a boca: a mandíbula acompanha somente a fala TTS.

## Avatar e voz

O ID de avatar vem do catálogo AVATARES junto do Assistente, por exemplo professor, engenheiro, medico ou robo. O editor tem **Escolher avatar**, com a lista do Assistente selecionado. Avatar ausente é recusado antes de iniciar o roteiro. A troca ocorre no ponto da tag e reinicia as poses do modelo. O avatar original é restaurado no fim, no erro e no cancelamento, sem alterar a configuração salva.

**Escolher voz** insere a tag pelo nome do provedor já configurado no Assistente. Para SAPI, use o nome instalado completo, por exemplo Microsoft Maria Desktop, se essa voz existir na máquina. Uma voz SAPI não instalada produz erro, sem substituição silenciosa. Para voz remota, use o identificador aceito pelo provedor; a resposta dele valida disponibilidade. A tag não troca o provedor nem as credenciais.

A voz vale para as falas seguintes, até outra tag. **voz=padrao** retorna à escolha inicial. A seleção é aplicada antes da síntese do trecho seguinte e fica restrita à execução atual. As tags de voz e avatar não são pronunciadas e a regeneração da IA precisa preservá-las exatamente.

Exemplo:

```text
[avatar=professor][voz=padrao]
[executar arquivo=assets/figura.png] Esta imagem continua na tela.
[executar arquivo=assets/ambiente.wav|inicio=00:00:05] Um som pode acompanhá-la.
[fechar som]
[avatar=engenheiro][voz=nova] Agora outro avatar e outra voz do provedor.
[executar arquivo=assets/filme.mp4|inicio=00:01:30]
[fechar arquivo]
```

O exemplo com nova pressupõe que essa voz existe no provedor configurado. Todos os recursos precisam estar dentro do PVA.


## Controle de fluxo

| Tag | Uso |
| --- | --- |
| [BLOCO:{NOME}] | Declara bloco, disponível somente por chamada; termina no próximo BLOCO ou no fim do texto. |
| [{NOME}] | Executa bloco e retorna após a chamada. [NOME] também chama quando há bloco com esse nome. |
| [GOTO:{NOME}] | Desvia para o bloco e encerra ao final dele, sem retorno. |
| [FIM] | Encerra a tarefa inteira e fecha as mídias. |
| [EVENT={EVENTO}:{BLOCO_NOME}] | Declara vínculo futuro, sem disparar sensores ou executar o bloco. |

Eventos preparados: DETECCAO_VOZ, DETECCAO_ROSTO, MAO_LEVANTADA e RECONHECIMENTO_PESSOA. Nomes descritivos com acentos também são aceitos. O fluxo principal termina antes da primeira declaração BLOCO; blocos não são percorridos automaticamente.

O [manual de blocos, eventos e comandos](blocos-eventos-comandos.md) documenta retorno, GOTO, FIM, nomes, limites, exemplos, prévia no editor e os comandos falados/digitados **carregar arquivo nome** e **chamar bloco nome**.
