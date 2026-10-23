# Blocos, eventos e comandos de carregamento

O editor cria e valida o roteiro. O Assistente atualizado executa o fluxo resultante, mantendo avatar e mídias no painel já existente. As tags de controle não são pronunciadas.

## Tags

| Tag | Efeito |
| --- | --- |
| `[BLOCO:{NOME}]` | Declara o início de um bloco. O corpo termina no próximo BLOCO ou no fim do arquivo. A declaração não executa o bloco. |
| `[{NOME}]` | Chama o bloco, executa seu corpo e volta ao ponto seguinte à chamada. Também aceita `[NOME]` quando existe um bloco com esse nome. |
| `[GOTO:{NOME}]` | Desvia para o bloco e encerra a execução ao final dele. Não retorna ao chamador, inclusive quando usado dentro de outro bloco. |
| `[FIM]` | Encerra toda a tarefa naquele ponto, inclusive os chamadores e as mídias ainda abertas. O texto seguinte não é executado. |
| `[EVENT={EVENTO}:{BLOCO_NOME}]` | Registra um vínculo de evento com um bloco para uso futuro. Não executa o bloco nesta versão. |

As chaves delimitadoras são opcionais nas formas longas: `[BLOCO:Inicio]`, `[GOTO:Inicio]` e `[EVENT=DETECCAO_VOZ:AoOuvir]` também são aceitas. A forma explícita de chamada é `[{Inicio}]`.

O fluxo principal é o texto antes da primeira declaração BLOCO. Ele termina ao encontrar essa declaração; não percorre os blocos por sequência. Se o arquivo começar com um BLOCO, seu carregamento apenas o deixa disponível para uma chamada posterior. Para executar um bloco automaticamente na abertura, escreva um GOTO ou uma chamada no fluxo principal.

O retorno da chamada curta foi definido explicitamente pelo usuário: após `[{NOME}]`, o roteiro volta ao comando seguinte. Não há necessidade de uma tag RETORNO. Um FIM dentro do bloco encerra também quem o chamou.

Voz, avatar e mídias alterados por um bloco continuam no estado resultante ao retornar; não existe restauração automática de estado a cada chamada. O encerramento da apresentação continua restaurando o avatar da configuração.

## Exemplo completo

```text
[EVENT={DETECCAO_VOZ}:{AoOuvir}]
[EVENT={DETECCAO_ROSTO}:{AoVerRosto}]
[EVENT={MAO_LEVANTADA}:{AoLevantarMao}]
[EVENT={RECONHECIMENTO_PESSOA}:{AoReconhecer}]

Olá. [{Saudacao}] Voltei ao fluxo principal.
[GOTO:{Encerramento}]

[BLOCO:{Saudacao}]
[sorriso] Bem-vindo à apresentação.

[BLOCO:{Encerramento}]
Obrigado pela atenção.
[FIM]
Este trecho não será executado.

[BLOCO:{AoOuvir}]
Este bloco está preparado para um evento futuro de voz.

[BLOCO:{AoVerRosto}]
Este bloco está preparado para um evento futuro de rosto.

[BLOCO:{AoLevantarMao}]
Este bloco está preparado para um evento futuro de mão levantada.

[BLOCO:{AoReconhecer}]
Este bloco está preparado para um evento futuro de reconhecimento.
```

Na abertura, o Assistente fala a saudação, volta ao fluxo principal e executa o encerramento pelo GOTO. Os quatro blocos associados aos eventos permanecem inativos.

## Eventos preparados

| Evento | Nome usado na tag |
| --- | --- |
| Detecção de voz | `DETECCAO_VOZ` |
| Detecção de rosto | `DETECCAO_ROSTO` |
| Detecção de mão levantada | `MAO_LEVANTADA` |
| Reconhecimento de pessoa | `RECONHECIMENTO_PESSOA` |

Também são aceitos os nomes descritivos, com espaços e acentos, como `[EVENT={Detecção de mão levantada}:{AoLevantarMao}]`. O seletor do editor mostra esses nomes descritivos.

Os vínculos de todo o arquivo são validados e ficam disponíveis no programa carregado por `LoadedFlow.EventCount` e `LoadedFlow.EventBinding`. Um evento pode apontar para mais de um bloco; repetir o mesmo vínculo é erro. Ainda não há disparador, assinatura de sensores, reconhecimento ou execução automática desses eventos. A entrada de uma transcrição de voz para os comandos descritos abaixo não dispara o EVENT de detecção de voz.

## Escrever ou dizer comandos

Com o Assistente disponível para nova entrada, use:

```text
carregar arquivo demonstracao
chamar bloco Saudacao
```

Os mesmos comandos passam pelo fluxo de texto digitado e pelo texto transcrito da voz. Chaves e pontuação final simples são aceitas: `chamar bloco {Saudacao}.` e `carregar arquivo {demonstracao}]`. Durante a apresentação, a captura contínua continua pausada, como antes; termine a execução ou use Esc para voltar à entrada de comandos. Os EVENTs não alteram esse comportamento.

A busca ocorre na pasta `%LOCALAPPDATA%/Assistente/RAG/`, ou em `ASSISTENTE_CONFIG_DIR/RAG/` quando essa variável estiver definida. O comando aceita somente nomes da biblioteca, não caminhos arbitrários. A comparação desconsidera extensão, maiúsculas, acentos e separadores usuais; pequenas diferenças de escrita são aceitas. Se dois candidatos tiverem proximidade semelhante, o Assistente informa a ambiguidade. Um nome completo com extensão pode desambiguar arquivos diferentes.

Um `.res` gerado ao lado de um `.pva` resolve para o pacote correspondente. Esse par não aparece como duas opções concorrentes.

- **PVA:** valida e executa o fluxo principal; mantém o arquivo carregado para chamadas posteriores.
- **SCRIPT:** roteiro UTF-8, com a mesma linguagem do editor. Recursos relativos devem existir na pasta `assets/` ao lado dele; o executor cria um pacote temporário validado antes de reproduzir.
- **TXT ou MD:** a presença de comandos executáveis fora de código identifica um roteiro; texto comum é documento de consulta.
- **RAG, RES independente, JSON ou CSV:** texto UTF-8 de consulta. Tags dentro desses documentos são dados; não executam blocos. `.rag` é tratado como texto/JSON de conhecimento, sem importação de índices vetoriais proprietários.

Essa entrada de documentos tradicionais suporta os formatos de texto listados acima. Não realiza extração de PDF, DOCX ou XLSX. Documentos devem ter até 1 MiB de texto UTF-8. A consulta envia o início e trechos associados aos termos da pergunta, limitados a 24.000 caracteres, para a IA já configurada.

Carregar outro arquivo substitui o arquivo atual. Ao carregar um documento tradicional, os blocos do script anterior deixam de estar disponíveis. Perguntas seguintes usam o documento como conhecimento, sem selecionar automaticamente outro PVA. Carregar um script reabilita o fluxo normal de apresentações.

Uma chamada após o término ou cancelamento da apresentação continua disponível porque o caminho do script é mantido. Cada nova chamada reabre e valida o arquivo atual no disco. Se ele tiver sido removido, alterado para um roteiro inválido ou não contiver mais o bloco, o Assistente apresenta o erro.

## Editor e prévia

Os botões **Bloco**, **GOTO**, **Chamar bloco**, **Evento futuro** e **FIM** inserem a tag na posição do cursor. **Prévia do bloco** valida o roteiro e abre o Assistente diretamente no bloco informado. A edição preserva desfazer/refazer. Referências podem ser escritas antes da declaração do bloco, mas precisam estar resolvidas ao validar ou salvar.

O salvamento conserva os comandos no PVA. O `.res` de consulta contém o texto de todos os blocos, sem declarações, chamadas, eventos ou FIM. Isso permite localizar conteúdo de blocos disponíveis, incluindo os ainda inativos; a reprodução segue o fluxo principal definido pelo autor. A geração de gestos pela IA deve preservar exatamente as tags de fluxo e todos os demais caracteres que não sejam gestos.

Na linha de comando, a prévia direta usa:

```text
assistente.exe --presentation-block Saudacao caminho/apresentacao.pva
```

## Validação e limites

Os nomes de blocos são únicos após normalização de caixa, acentos, espaços e sublinhados, com até 80 caracteres. Nomes de comandos existentes, como `sorriso`, e as palavras BLOCO, GOTO, EVENT e FIM são reservados. Até 256 blocos são aceitos. Chamadas inexistentes, vínculos inválidos, ciclos diretos/indiretos e tags malformadas são recusados. Tags dentro de código, links ou escapadas com barra invertida são literais.

A execução permite até 32 níveis de chamadas, 4.096 expansões de blocos, menos de 4.096 eventos de reprodução e até 1 MiB de roteiro expandido. Esses limites impedem que chamadas sucessivas produzam uma execução sem controle. FIM é entregue ao painel na fronteira correta do roteiro, depois do trecho de fala anterior, e fecha os canais de mídia sem esperar pelo som de fundo restante.

Os testes são executados na ordem editor → Assistente:

```text
python scripts/build_presentations.py --target tests
python tests/run_presentation_flow.py build/presentations --model AVATARES/professor/modelo.gltf
```

O teste valida controles do editor, desfazer/refazer, compilação, arquivos salvos, fala sem tags, navegação entre blocos, retorno, FIM, eventos inativos, nomes semelhantes, documento tradicional como conhecimento e comandos pelo retorno da transcrição. A transcrição é simulada no callback real; reconhecimento físico por microfone não é medido. A IA e o áudio remoto usam um servidor HTTP local de teste.
