# Guia de comandos do Assistente e do Editor de Apresentações

Este guia explica como escrever roteiros com fala, blocos, imagens, vídeos, sons, slides, avatar e voz. Também mostra os comandos que podem ser digitados ou falados ao Assistente para carregar um arquivo e executar um bloco.

## 1. Como começar

1. Abra o Editor de Apresentações e escreva o texto que será apresentado.
2. Insira os comandos nos pontos em que deseja mudar o comportamento. Use os botões do editor para escolher mídias, avatar e voz.
3. Use **Validar** para conferir o roteiro e suas referências.
4. Use **Prévia no Assistente** para testar a apresentação completa ou **Prévia do bloco** para testar um bloco.
5. Salve como `.pva`. O pacote reúne o roteiro e os recursos usados.

O texto comum é apresentado e, quando a fala automática está habilitada, pronunciado. As tags reconhecidas entre colchetes são executadas e não são lidas em voz alta. Elas atuam depois do trecho anterior e antes do trecho seguinte.

```text
[sorriso] Olá! Bem-vindo à apresentação.
[levantar mao direita] Podemos começar.
[abaixar mao direita] Vamos ao conteúdo.
```

Os exemplos devem ser copiados sem as cercas de código Markdown. Dentro do próprio roteiro, comandos escritos entre crases ou escapados, como `\[FIM]`, são texto literal. Rótulos de links Markdown também são preservados como texto.

## 2. Referência rápida

| Comando | Para que serve |
| --- | --- |
| `[BLOCO:{Nome}]` | Declara um bloco que poderá ser chamado. |
| `[{Nome}]` | Executa o bloco e retorna ao ponto seguinte à chamada. |
| `[GOTO:{Nome}]` | Vai ao bloco e encerra a tarefa quando ele termina. |
| `[FIM]` | Encerra a tarefa inteira e fecha as mídias. |
| `[EVENT={Evento}:{Nome}]` | Prepara o vínculo de um evento futuro com um bloco. |
| `[avatar=professor]` | Escolhe um avatar instalado. |
| `[voz=padrao]` | Usa novamente a voz inicial da apresentação. |
| `[voz=identificador]` | Escolhe outra voz disponível no provedor configurado. |
| `[executar arquivo=assets/figura.png]` | Abre uma mídia incluída no pacote. |
| `[fechar arquivo]` | Fecha a mídia visual e o som de recurso. |
| `[fechar som]` | Fecha somente o som de recurso. |
| `[proximo slide]` | Avança no PPTX aberto. |
| `[slide anterior]` | Volta no PPTX aberto. |
| `[ir para slide=3]` | Abre o slide indicado, numerado a partir de 1. |
| `[sorriso]` | Solicita um gesto ou expressão do avatar. |
| `[articulacao=head,y,15,800,suave]` | Move uma articulação permitida do avatar. |

Os comandos de arquivo, fluxo e articulação devem fazer parte de um roteiro validado. Escrevê-los numa conversa comum não equivale a executar uma apresentação. Os comandos de entrada **carregar arquivo** e **chamar bloco** são explicados na seção 11.

## 3. Blocos e chamadas com retorno

### Declarar um bloco: `[BLOCO:{Nome}]`

Um bloco é uma parte nomeada do roteiro. Seu conteúdo começa depois da declaração e termina na próxima declaração `[BLOCO:...]` ou no fim do arquivo.

A declaração, sozinha, não executa o conteúdo. O fluxo principal é somente o texto que aparece antes do primeiro bloco. Ao chegar à primeira declaração, esse fluxo termina; os blocos seguintes ficam disponíveis para chamadas.

### Chamar um bloco: `[{Nome}]`

A chamada executa o bloco e depois continua no ponto seguinte à chamada. Não é necessário escrever um comando de retorno.

```text
Vamos começar.
[{Saudacao}]
Agora continuamos a explicação principal.

[BLOCO:{Saudacao}]
[sorriso] Seja bem-vindo!
```

Ordem da fala: “Vamos começar.” → “Seja bem-vindo!” → “Agora continuamos a explicação principal.”

Também é aceita a forma `[Saudacao]` quando existe um bloco com esse nome. Prefira `[{Saudacao}]`, que deixa a intenção de chamada explícita e acusa referência inexistente na validação.

É possível chamar um bloco declarado mais abaixo e chamar outro bloco de dentro de um bloco. Chamadas que formem ciclos, como A chamar B e B chamar A, são recusadas.

Se um bloco trocar avatar, voz ou mídia, essas escolhas continuam valendo após o retorno. A chamada não restaura automaticamente o estado anterior.

### Regras para nomes

- Use nomes curtos e descritivos, como `Introducao`, `ExplicacaoProduto` ou `Encerramento`.
- São aceitos até 80 caracteres por nome e até 256 blocos por roteiro.
- Maiúsculas, acentos, espaços e sublinhados são normalizados na comparação; evite nomes que só diferem nesses detalhes.
- Os nomes precisam ser únicos e não podem ser palavras reservadas como `BLOCO`, `GOTO`, `EVENT`, `FIM` ou nomes de comandos existentes, como `sorriso`.
- Não use colchetes, chaves, dois-pontos, sinal de igual, barra vertical, barras, crases ou caracteres de controle dentro do nome.

As chaves são delimitadores opcionais nas formas longas: `[BLOCO:Saudacao]` e `[GOTO:Saudacao]` também são aceitos.

## 4. Desvio e encerramento

### Desviar: `[GOTO:{Nome}]`

O GOTO transfere a execução ao bloco indicado. Ao terminar esse bloco, a tarefa termina. Não há retorno ao ponto do GOTO, mesmo quando ele aparece dentro de uma chamada com retorno.

```text
Apresentação iniciada.
[GOTO:{Encerramento}]
Este texto não será executado.

[BLOCO:{Encerramento}]
Obrigado pela atenção.
```

### Encerrar imediatamente: `[FIM]`

O FIM encerra a tarefa inteira, incluindo todas as chamadas em andamento, e fecha as mídias abertas. O trecho de fala anterior termina antes de o comando ser aplicado; o som de fundo restante não prolonga a tarefa.

```text
Esta é a última frase.
[FIM]
Este texto não será executado.
```

Um FIM dentro de um bloco também encerra o roteiro que o chamou. Para apenas retornar ao chamador, deixe o bloco chegar ao seu limite, sem FIM.

## 5. Eventos preparados para uso futuro

Sintaxe:

```text
[EVENT={EVENTO}:{BLOCO_NOME}]
```

| Evento | Identificador |
| --- | --- |
| Detecção de voz | `DETECCAO_VOZ` |
| Detecção de rosto | `DETECCAO_ROSTO` |
| Detecção de mão levantada | `MAO_LEVANTADA` |
| Reconhecimento de pessoa | `RECONHECIMENTO_PESSOA` |

```text
[EVENT={DETECCAO_VOZ}:{AoOuvir}]
[EVENT={DETECCAO_ROSTO}:{AoVerRosto}]
[EVENT={MAO_LEVANTADA}:{AoLevantarMao}]
[EVENT={RECONHECIMENTO_PESSOA}:{AoReconhecer}]
```

Também é aceito um nome descritivo, por exemplo `[EVENT={Detecção de mão levantada}:{AoLevantarMao}]`, ou a forma sem chaves `[EVENT=DETECCAO_VOZ:AoOuvir]`.

**Nesta versão, os eventos apenas registram e validam os vínculos.** Não ligam sensores, não reconhecem pessoas e não executam blocos automaticamente. Os blocos associados devem existir e podem ser chamados normalmente pelo autor ou pelo comando de entrada.

Um evento pode ter mais de um bloco associado. Repetir exatamente o mesmo vínculo é erro. As declarações de todo o arquivo são registradas no carregamento, independentemente de sua posição no fluxo. Uma transcrição de voz usada para dar um comando ao Assistente não dispara o EVENT de detecção de voz.

## 6. Escolher avatar e voz

### Avatar: `[avatar=identificador]`

```text
[avatar=professor] Vou apresentar a introdução.
[avatar=engenheiro] Agora vamos aos detalhes técnicos.
```

Use **Escolher avatar** no editor para obter um identificador do catálogo instalado no Assistente selecionado. Os exemplos exigem que esses avatares existam na instalação. Um identificador ausente é recusado.

A troca ocorre no ponto da tag e reinicia as poses do modelo. Ao terminar, cancelar ou ocorrer um erro, o Assistente restaura o avatar original. A escolha do roteiro não altera a configuração salva.

### Voz: `[voz=identificador]`

```text
[voz=padrao] Esta fala usa a voz inicial da apresentação.
```

Use **Escolher voz** para inserir uma opção compatível com o provedor já configurado. A voz selecionada vale para as falas seguintes até outra tag de voz.

- **SAPI do Windows:** informe o nome completo de uma voz instalada. Exemplo, somente se estiver disponível: `[voz=Microsoft Maria Desktop]`.
- **Provedor remoto:** informe o identificador aceito por ele. Exemplo, somente se o provedor o oferecer: `[voz=nova]`.
- **Restaurar:** `[voz=padrao]` volta à voz que estava configurada no início da tarefa.

A tag não muda o provedor nem suas credenciais. Uma voz SAPI inexistente gera erro; a disponibilidade de uma voz remota depende do provedor. A seleção fica restrita à execução atual.

## 7. Imagens, vídeos e sons

### Incluir e abrir

Use **Inserir mídia** no editor. Ele importa o recurso e insere seu caminho na posição do cursor. O nome interno pode ser diferente do nome original; preserve o caminho gerado.

```text
[executar arquivo=assets/figura.png] Observe esta imagem.
[executar arquivo=assets/aula.mp4] Vamos assistir ao vídeo.
[executar arquivo=assets/ambiente.wav] Este som acompanha a apresentação.
```

`[abrir arquivo=assets/figura.png]` é uma forma equivalente a `executar arquivo`.

Os caminhos devem apontar para recursos relativos dentro de `assets/`. Os nomes deste guia são exemplos: antes de reproduzi-los, importe os arquivos correspondentes. URLs e caminhos arbitrários do computador não são aceitos nessas tags.

| Recurso | Formatos |
| --- | --- |
| Imagem | PNG, JPG, JPEG e BMP |
| Vídeo | AVI, WMV e MP4, conforme os codecs disponíveis no Windows |
| Som | WAV, MP3 e WMA, conforme os codecs disponíveis no Windows |
| Slides | PPTX, com PowerPoint instalado e disponível |

### Começar num ponto do vídeo ou som

Acrescente `|inicio=hh:mm:ss` dentro da tag:

```text
[executar arquivo=assets/aula.mp4|inicio=00:01:30]
O vídeo começa em um minuto e trinta segundos.

[executar arquivo=assets/ambiente.wav|inicio=00:00:10]
O som começa em dez segundos.
```

Cada campo precisa ter exatamente dois dígitos: horas de `00` a `99`, minutos e segundos de `00` a `59`. Sem esse parâmetro, a reprodução começa em `00:00:00`. O ponto inicial deve ser anterior ao fim real do arquivo. Imagens e PPTX não aceitam início temporal.

Esse parâmetro escolhe o ponto inicial do arquivo de mídia; não agenda o comando para um horário futuro nem define um ponto de parada.

### Fechar e combinar recursos

```text
[fechar som]
[fechar arquivo]
```

- Há um canal visual: imagem, vídeo ou PPTX. Abrir outro recurso visual substitui o anterior.
- Há um canal independente para som de recurso. Abrir outro som substitui o anterior e preserva a mídia visual.
- Abrir outra mídia visual preserva o som de recurso.
- `[fechar som]` fecha somente esse som.
- `[fechar arquivo]` fecha a mídia visual e o som de recurso.

O áudio do vídeo e a fala sintetizada são independentes do canal de som de recurso. Sons de fundo não movimentam a boca do avatar; a boca acompanha a fala sintetizada.

### Onde a mídia aparece

Os recursos visuais aparecem numa janela dentro do painel de texto da conversa. Durante essa exibição, o texto pode ficar temporariamente oculto e ser restaurado depois. **O avatar continua visível ao lado da mídia.** Reproduzir apenas som não exige esconder o texto.

## 8. Apresentações PowerPoint

```text
[executar arquivo=assets/apresentacao.pptx] Este é o primeiro slide.
[proximo slide] Vamos ao segundo.
[slide anterior] Voltamos ao primeiro.
[ir para slide=3] Agora estamos no terceiro.
[fechar arquivo]
```

O PPTX abre no slide 1. Os comandos de navegação exigem um PPTX ativo e um número existente na apresentação. Abrir imagem ou vídeo substitui a apresentação visual.

A reprodução usa o PowerPoint instalado, ativado e disponível na sessão do Windows. O arquivo mostrado é a apresentação original, incorporada ao painel visual. Arquivos com macros, como PPTM, não são aceitos. O encerramento fecha a apresentação aberta pelo roteiro e preserva as demais apresentações do usuário.

## 9. Gestos do avatar

Os nomes abaixo são os 40 comandos reconhecidos. Cada tag solicita a ação indicada; o resultado visual depende das animações disponíveis no avatar escolhido. Um modelo sem determinada animação pode usar a melhor alternativa disponível e apresentar um aviso.

| Tag | Ação solicitada |
| --- | --- |
| `[sorriso]` | Manter um sorriso. |
| `[neutro]` | Limpar sorriso, mão levantada e gesto transitório. |
| `[aplausos]` | Bater palmas. |
| `[levantar mao direita]` | Levantar e manter a mão direita. |
| `[abaixar mao direita]` | Baixar a mão direita. |
| `[aceno]` | Acenar. |
| `[caminhar]` | Demonstrar caminhada no lugar. |
| `[piscar]` | Piscar os olhos. |
| `[concordar]` | Fazer gesto de concordância. |
| `[negar]` | Fazer gesto de negação. |
| `[pensar]` | Fazer gesto de reflexão. |
| `[explicar]` | Fazer gesto de explicação. |
| `[apontar direita]` | Apontar para a direita. |
| `[apontar esquerda]` | Apontar para a esquerda. |
| `[levantar mao esquerda]` | Levantar a mão esquerda. |
| `[abaixar mao esquerda]` | Baixar a mão esquerda. |
| `[levantar ambas maos]` | Levantar as duas mãos. |
| `[abaixar ambas maos]` | Baixar as duas mãos. |
| `[olhar esquerda]` | Dirigir o olhar à esquerda. |
| `[olhar direita]` | Dirigir o olhar à direita. |
| `[olhar frente]` | Dirigir o olhar para a frente. |
| `[surpresa]` | Expressar surpresa. |
| `[triste]` | Expressar tristeza. |
| `[serio]` | Adotar expressão séria. |
| `[rir]` | Solicitar expressão ou gesto de riso. |
| `[comemorar]` | Comemorar. |
| `[cumprimentar]` | Fazer gesto de cumprimento. |
| `[positivo]` | Fazer gesto positivo. |
| `[negativo]` | Fazer gesto negativo. |
| `[abrir bracos]` | Abrir os braços. |
| `[fechar bracos]` | Fechar os braços. |
| `[cruzar bracos]` | Cruzar os braços. |
| `[descruzar bracos]` | Descruzar os braços. |
| `[sentar]` | Solicitar movimento de sentar. |
| `[levantar]` | Solicitar movimento de levantar. |
| `[passo atras]` | Solicitar um passo para trás. |
| `[passo frente]` | Solicitar um passo para a frente. |
| `[dancar]` | Dançar. |
| `[parar gesto]` | Parar o gesto. |
| `[relaxar]` | Solicitar pose relaxada. |

A direita e a esquerda são as do personagem. A mão direita dele aparece à esquerda para quem o observa de frente.

Maiúsculas, acentos e espaços extras são aceitos nos nomes dos gestos. Também existem aliases como `[sorrir]`, `[aplaudir]`, `[acenar]` e `[caminhada]`. Prefira as formas da tabela para padronizar seus roteiros.

Nos modelos compatíveis, sorriso e mão levantada podem permanecer até outra instrução ou encerramento. Aplausos, aceno e caminhada no lugar são gestos transitórios de até 2,4 segundos. Esses comandos não ativam reconhecimento por câmera nem geram efeitos sonoros.

## 10. Movimento de articulações

Esta opção é voltada a autores que conhecem o esqueleto do modelo escolhido.

```text
[articulacao=osso,eixo,angulo,duracao,interpolacao]
```

| Campo | Como preencher |
| --- | --- |
| `osso` | Nome exato no modelo, com maiúsculas e minúsculas preservadas. |
| `eixo` | `x`, `y` ou `z`, no espaço local do osso. |
| `angulo` | Graus relativos à pose inicial; use ponto em valores decimais. |
| `duracao` | Inteiro de 50 a 10000 milissegundos. |
| `interpolacao` | `linear` ou `suave`. |

| Ossos permitidos | Limite absoluto do ângulo |
| --- | --- |
| `head`, `neck01`, `neck02`, `neck03` | 25° |
| `spine01`, `spine02`, `spine03`, `spine04`, `spine05` | 15° |
| `upperarm01.L`, `upperarm01.R`, `lowerarm01.L`, `lowerarm01.R` | 90° |
| `wrist.L`, `wrist.R` | 35° |

```text
[articulacao=head,y,15,800,suave] Observe este lado.
[articulacao=head,y,0,800,suave] Agora voltamos à posição inicial.
```

O osso deve existir no avatar. Cada osso mantém um alvo de eixo/ângulo por vez; a pose permanece até outra instrução. Use ângulo zero para retornar. Encerrar ou cancelar limpa essas poses. Mandíbula, lábios, língua e ossos fora da lista são recusados. Os limites são definidos para os modelos compatíveis; não são calculados automaticamente para um modelo externo.

## 11. Comandos digitados ou falados ao Assistente

### Carregar um arquivo

```text
carregar arquivo demonstracao
```

O Assistente procura na biblioteca RAG pelo nome informado. A busca desconsidera extensão, maiúsculas, acentos e separadores usuais e aceita pequenas diferenças de escrita. Havendo nomes muito semelhantes, informa a ambiguidade. Um nome completo com extensão pode ajudar a escolher.

```text
carregar arquivo demonstracao.pva
carregar arquivo {demonstracao}
```

A busca fica na biblioteca; o comando não recebe caminhos arbitrários nem pesquisa todas as pastas do computador.

### Chamar um bloco do arquivo carregado

```text
chamar bloco Saudacao
chamar bloco {Saudacao}
```

É necessário ter um script carregado que contenha o bloco. O Assistente mantém o arquivo disponível após o término ou cancelamento da apresentação. Cada nova chamada reabre e valida o arquivo no disco.

Carregar outro arquivo substitui o contexto anterior. Se o novo arquivo for um documento de consulta, os blocos do script anterior deixam de estar disponíveis.

Os comandos funcionam com texto digitado e com texto transcrito da voz. Durante a apresentação, a captura contínua de voz fica pausada. Espere o término ou use **Esc** para voltar à entrada de comandos. Os eventos futuros não mudam essa regra.

### Como o tipo de arquivo é tratado

| Tipo | Comportamento ao carregar |
| --- | --- |
| `.pva` | Valida o pacote e executa seu fluxo principal. |
| `.script` | Interpreta como roteiro UTF-8; mídias devem existir em `assets/` ao lado do arquivo. |
| `.txt` ou `.md` | Com comandos executáveis fora de código, trata como roteiro; texto comum vira documento de consulta. |
| `.rag`, `.res` independente, `.json` ou `.csv` | Usa como conhecimento UTF-8, sem executar tags. |
| `.res` com `.pva` de mesmo nome ao lado | Resolve para o pacote PVA correspondente. |

Um arquivo `.rag` é tratado como conteúdo de texto ou JSON, sem importação de índices vetoriais proprietários. Essa entrada suporta os formatos textuais listados; não extrai conteúdo de PDF, DOCX ou XLSX. O documento deve ser UTF-8, não vazio e ter até 1 MiB.

Depois de carregar um documento tradicional, as perguntas usam esse documento como conhecimento, com trechos selecionados conforme a pergunta. Enquanto esse contexto estiver ativo, outro PVA não é selecionado automaticamente. Carregar um script permite voltar ao fluxo de apresentações.

## 12. Biblioteca RAG e arquivo `.res`

A pasta padrão da biblioteca é:

```text
%LOCALAPPDATA%\Assistente\RAG\
```

Se `ASSISTENTE_CONFIG_DIR` estiver definida, a biblioteca fica na subpasta `RAG` desse diretório.

Ao salvar pelo editor, o pacote é copiado para a biblioteca e é gerado um arquivo de mesmo nome-base com extensão `.res`:

```text
demonstracao.pva  → pacote com roteiro e recursos
demonstracao.res  → texto de consulta da apresentação
```

O `.res` reúne o texto dos blocos, incluindo os que não são executados na abertura, e remove as tags de comando. Ele permite localizar o assunto da apresentação. Não substitui o roteiro nem define a ordem de reprodução.

Quando a IA identifica que a apresentação é adequada à solicitação, o Assistente reproduz o **pacote PVA original**, seguindo suas tags e seus recursos. Ele não lê o `.res` como se fosse a apresentação completa. Um `.res` sem pacote correspondente pode ser carregado explicitamente como documento tradicional.

Com o Assistente aberto, o monitor da biblioteca também verifica pacotes copiados para essa pasta e gera ou atualiza o `.res` após validar o PVA. Um pacote incompleto ou inválido não é publicado para reprodução até estar válido.

## 13. Exemplo completo, sem arquivos de mídia

Este exemplo demonstra chamada com retorno, GOTO, FIM e os quatro eventos preparados. Pode ser escrito no editor sem importar recursos externos.

```text
[EVENT={DETECCAO_VOZ}:{AoOuvir}]
[EVENT={DETECCAO_ROSTO}:{AoVerRosto}]
[EVENT={MAO_LEVANTADA}:{AoLevantarMao}]
[EVENT={RECONHECIMENTO_PESSOA}:{AoReconhecer}]

Olá! Vamos começar.
[{Saudacao}]
Voltamos ao fluxo principal.
[{Explicacao}]
[GOTO:{Encerramento}]

[BLOCO:{Saudacao}]
[sorriso] Seja bem-vindo à apresentação.

[BLOCO:{Explicacao}]
Um bloco reúne uma parte do roteiro e pode ser chamado pelo nome.

[BLOCO:{Encerramento}]
Obrigado pela atenção.
[FIM]
Este trecho não será executado.

[BLOCO:{AoOuvir}]
Este bloco está reservado para um evento futuro de voz.

[BLOCO:{AoVerRosto}]
Este bloco está reservado para um evento futuro de rosto.

[BLOCO:{AoLevantarMao}]
Este bloco está reservado para um evento futuro de mão levantada.

[BLOCO:{AoReconhecer}]
Este bloco está reservado para um evento futuro de reconhecimento.
```

Ao abrir, o roteiro fala a saudação, retorna ao principal, chama a explicação e segue ao encerramento. Os quatro blocos dos eventos ficam inativos. Depois do término, você pode digitar `chamar bloco Explicacao` para ouvir novamente essa parte.

## 14. Pausa, cancelamento e término

| Controle | Efeito durante a apresentação |
| --- | --- |
| **P** | Pausa ou retoma os canais de reprodução. |
| **Esc** | Cancela a apresentação, fecha as mídias e restaura o avatar. |
| `[FIM]` | Termina a tarefa no ponto definido pelo autor. |

Em um roteiro simples que chega normalmente ao fim do texto, o executor aguarda vídeo ou som ainda em reprodução. Uma imagem estática ou PPTX não prolonga a tarefa. FIM e o encerramento do fluxo por GOTO ou limite de bloco fecham os recursos ao concluir a tarefa. O fim de um bloco chamado com retorno apenas devolve o controle ao chamador.

Uma síntese de fala já em andamento pode precisar retornar antes de o cancelamento terminar de liberar os recursos.

## 15. Dúvidas e erros frequentes

| Situação | O que conferir |
| --- | --- |
| Um bloco não executou na abertura. | Coloque uma chamada ou GOTO antes do primeiro BLOCO. Declarações não executam seus corpos. |
| A fala não voltou depois de um bloco. | Use `[{Nome}]` para retornar; GOTO encerra ao final do destino. Remova FIM do bloco se deseja voltar. |
| Bloco inexistente ou duplicado. | Confira o nome e a normalização de acentos, caixa, espaços e sublinhados. |
| Evento não disparou o bloco. | Os eventos estão preparados, sem disparadores nesta versão. |
| Avatar ou voz recusados. | Escolha uma opção instalada ou disponível no provedor configurado. |
| Mídia não encontrada. | Importe pelo editor e preserve o caminho interno gerado. |
| Vídeo ou som não começa no ponto pedido. | Confira o formato de dois dígitos e se o horário está dentro da duração do arquivo. |
| Slide não abre. | Confira o PowerPoint e se o número existe no PPTX ativo. |
| Gesto não aparece como esperado. | Confira as animações oferecidas pelo modelo escolhido. |
| Comando apareceu literalmente. | Confira a grafia e se ele está entre crases, escapado ou dentro de uma marcação Markdown literal. |
| “Chamar bloco” não encontra mais o roteiro. | Confira se outro documento foi carregado ou se o arquivo original mudou ou foi removido. |
| Nome de arquivo ambíguo. | Informe um nome mais específico, incluindo a extensão quando necessário. |

Valide sempre antes da prévia. Referências inexistentes, ciclos entre blocos e tags malformadas são recusados. A execução admite até 32 níveis de chamadas, 4.096 expansões de blocos e 1 MiB de roteiro expandido; dividir conteúdo muito grande em apresentações menores facilita a edição.

## 16. Boas práticas de autoria

- Mantenha o fluxo inicial antes das declarações de blocos.
- Use chamada com retorno para trechos reutilizáveis e GOTO para encaminhar ao encerramento.
- Use os seletores do editor para mídias, avatar e voz.
- Teste primeiro cada bloco e depois a apresentação completa.
- Ao usar **Gerar movimentos IA**, revise os gestos e a prévia. O editor exige que a geração preserve o texto e todas as demais tags; alterações inválidas são recusadas.
- Salve e distribua o `.pva` completo para manter roteiro e recursos juntos.

---

Documentação correspondente aos comandos implementados no Editor de Apresentações e no Assistente. Os quatro eventos da seção 5 permanecem preparados para implementação futura.
