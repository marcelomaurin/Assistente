# Projeto técnico — Geração do RES a partir do PVA

**Projeto:** Assistente — Editor de Apresentações e Biblioteca RAG  
**Data:** 23/10/2026  
**Status:** proposta técnica para implementação e homologação  
**Repositório:** [marcelomaurin/Assistente](https://github.com/marcelomaurin/Assistente)  
**Escopo:** aprimorar o fluxo existente; não criar outro formato de apresentação nem outro programa.

Atualização de validação em 24/10/2026: o digest agora identifica o PVA completo, inclusive mídias; a atualização confere esse digest mesmo quando tamanho e timestamp não mudam. Erros retiram a entrada afetada do catálogo sem apagar arquivos do usuário. Há regressões para corrupção com metadados preservados e alteração apenas de mídia. A proposta de experiência do editor e a serialização transacional do par continuam sendo objetivos de projeto. Veja o [relatório](../VALIDACAO_2026-10-24.md).

## 1. Objetivo

Estabelecer uma regra de arquitetura obrigatória:

> **O arquivo `.pva` é a única fonte oficial da apresentação. O arquivo `.res` é um artefato textual, descartável e reproduzível, sempre gerado pela leitura e validação do conteúdo de um `.pva` real.**

Nenhuma rotina poderá criar ou atualizar um `.res` diretamente a partir do texto que ainda está no editor, de um prompt de IA, de um cache ou de outro arquivo `.res`.

O RAG consulta o `.res` para localizar assuntos. O Assistente executa somente o `.pva` validado, com roteiro, mídias, avatar, voz e comandos preservados.

## 2. Situação do código em 23/10/2026

A implementação já contém a base necessária:

| Componente | Fonte | Comportamento verificado |
| --- | --- | --- |
| Salvamento | `src/presentation_editor_ui.pas` — `SavePackage` | Executa `ExportTo(FileName)` e depois `PublishPresentation(FileName)` |
| Empacotamento | `src/presentation_package.pas` — `TPVAPackage` | Exporta/carrega ZIP PVA, valida manifesto, roteiro e integridade dos recursos |
| Extração | `src/presentation_rag.pas` — `PlainPackage` | Abre o PVA, lê `P.Script`, remove diretivas de fluxo e extrai `PlainText` |
| Publicação | `src/presentation_rag.pas` — `PublishPresentation` | Copia PVA para a biblioteca e escreve RES com o mesmo nome-base |
| Reindexação | `src/presentation_rag.pas` — `Refresh` e `TPresentationRAGMonitor` | Reexamina PVA e recria RES; monitor aproximadamente a cada 2 s |
| Seleção | `src/agent_manager.pas` | Ranqueia candidatos, consulta o modelo e recebe ID estruturado |
| Reprodução | `src/main.pas` — `OnAgentComplete` | Revalida a escolha e chama `StartPresentation` |

**Importante:** o projeto abaixo é de **fortalecimento e formalização**, não de implementação do zero. O RAG atual faz ranqueamento por termos e decisão por LLM; não exige embeddings ou banco vetorial.

## 3. Fluxo obrigatório

```text
[Editor Lazarus]
      |
      | Validar roteiro e recursos
      v
[ExportTo: salvar arquivo.pva]
      |
      v
[PublishPresentation]
      |
      | Ler o PVA salvo (nunca o conteúdo em memória do editor)
      | Verificar estrutura, manifesto, roteiro, mídias e limites
      | Calcular identificador SHA-256 do pacote completo
      v
[Extrair texto do roteiro a partir desse PVA]
      |
      | Incluir texto de todos os blocos, inclusive os não executados na abertura
      | Excluir tags executáveis (movimentos, mídia, slides, controle, voz etc.)
      | Preservar texto humano, acentos, UTF-8 e ordem lógica
      v
[Gerar arquivo.res em UTF-8]
      |
      | Garantir correspondência entre RES e PVA publicado
      v
[%LOCALAPPDATA%/Assistente/RAG/]
      |-- arquivo.pva  (fonte oficial)
      `-- arquivo.res  (índice derivado)
      |
      v
[Consulta RAG -> seleção -> validação do PVA -> reprodução do PVA]
```

Se `ASSISTENTE_CONFIG_DIR` estiver definido, usar `ASSISTENTE_CONFIG_DIR/RAG/` como diretório da biblioteca, preservando a regra atual.

### Invariantes obrigatórias

**INV-01 — Fonte única:** `RES = ExtrairTexto(Validar(PVA))`.  
**INV-02 — Origem rastreável:** a rotina de extração recebe o caminho do PVA efetivamente salvo/publicado, e não um roteiro passado pelo editor.  
**INV-03 — Integridade:** um PVA inválido, incompleto, adulterado ou fora dos limites não deve entrar no catálogo.  
**INV-04 — Sincronismo:** um RES antigo ou adulterado não pode ser usado em uma seleção enquanto não corresponder ao PVA atual.  
**INV-05 — Execução:** o Assistente nunca executa tags encontradas no RES nem reconstrói a apresentação a partir dele.  
**INV-06 — Reprodutibilidade:** com o mesmo PVA e a mesma versão do extrator, gerar bytes idênticos de RES.  
**INV-07 — Recuperação:** falhas entre publicação do PVA e atualização do RES não podem deixar a biblioteca oferecendo um par inconsistente.  
**INV-08 — Compatibilidade:** continuar aceitando pacotes PVA v1 válidos já existentes, sem exigir migração de formato.

## 4. Requisitos funcionais

| ID | Requisito | Prioridade |
| --- | --- | --- |
| RF-01 | Salvar primeiro o PVA, validá-lo e apenas depois iniciar a publicação RAG | P0 |
| RF-02 | Abrir o PVA por `TPVAPackage.Load` e extrair seu `script.txt` validado | P0 |
| RF-03 | Produzir RES texto UTF-8 com todo o conteúdo apresentável, incluindo blocos | P0 |
| RF-04 | Remover do RES comandos de gestos, articulações, mídia, slides, avatar, voz, fluxo e controle sem eliminar texto comum | P0 |
| RF-05 | Gravar o RES com o mesmo nome-base do PVA no diretório RAG | P0 |
| RF-06 | Regenerar RES após alterações no PVA, inclusive quando o nome e tamanho não mudarem | P0 |
| RF-07 | Detectar e regenerar RES apagado, manualmente editado ou incompatível | P0 |
| RF-08 | Não oferecer PVA inválido, RES órfão ou pacote ainda sendo copiado | P0 |
| RF-09 | Impedir colisões silenciosas de nomes entre apresentações distintas; apresentar aviso ao autor quando houver substituição | P1 |
| RF-10 | Exibir no editor estados distinguíveis: PVA salvo / RAG publicado / publicação falhou | P1 |
| RF-11 | Permitir reconstruir todos os RES válidos usando somente os PVA da biblioteca | P1 |
| RF-12 | Exibir diagnóstico por arquivo durante reindexação, sem expor tokens e dados confidenciais | P1 |

**Fora do escopo:** transformar RES em formato executável; indexar diretamente PPTX/PDF; adicionar embeddings; sincronizar RAG pela internet; remover arquivos pessoais sem consentimento.

## 5. Projeto de implementação

### P0-A — Consolidar a extração como função pura sobre PVA

**Arquivo:** `src/presentation_rag.pas`.

- Manter `PlainPackage(FileName, out Digest)` ou refatorar para uma função com contrato explícito.
- A primeira operação deve ser abrir o PVA via `TPVAPackage.Load`; erros interrompem a publicação.
- Extrair do `P.Script` validado, passando pela análise de fluxo e pelo parser de comandos já existentes.
- Documentar se comentários, links literais e trechos escapados permanecem texto, e testar cada caso.
- Garantir que RES contenha exclusivamente conteúdo de consulta, sem caminhos de recursos nem tags executáveis.

### P0-B — Publicação consistente do par

**Arquivo:** `src/presentation_rag.pas`.

Estratégia recomendada:

1. Salvar/exportar PVA no destino escolhido pelo usuário.
2. Copiar os **bytes do PVA salvo** para um arquivo temporário privado na biblioteca.
3. Validar esse PVA temporário, calcular SHA-256 do pacote completo e gerar o RES exclusivamente a partir dele.
4. Preparar e sincronizar o RES temporário antes de expor a nova versão.
5. Substituir os arquivos finais com operações de troca seguras, serializando publicador e monitor para o mesmo nome-base.
6. Validar a correspondência no catálogo antes de permitir seleção ou reprodução.
7. Se ocorrer falha entre as duas substituições, excluir temporariamente a entrada inconsistente do catálogo e reprocessá-la a partir do PVA no próximo ciclo.

Duas substituições de arquivos no Windows **não compõem uma transação atômica única**. Portanto, a correção depende também da regra de não oferecer pares inconsistentes e da recuperação automática; não alegar atomicidade do par sem essa proteção.

**Integridade:** a garantia de correspondência deve considerar SHA-256 do **pacote PVA completo**, incluindo mídias, além da validação de roteiro já existente. O digest atual do roteiro, isoladamente, não identifica alterações apenas nos recursos binários.

### P0-C — Atualização e autocorreção

**Arquivo:** `src/presentation_rag.pas`, método `Refresh`.

- O monitor continuará observando arquivos `.pva` e não utilizará RES órfãos para seleção automática.
- Alterações devem ser detectadas por hash do PVA ou por validação equivalente, **não exclusivamente por tamanho + timestamp**.
- Caso RES esteja ausente, adulterado ou seja de geração anterior, reconstruir a partir do PVA.
- Em caso de escrita parcial, pacote inválido ou permissão negada, preservar o último arquivo do usuário e registrar diagnóstico.
- Proibir que o cache em memória represente como atual uma versão antiga do par.

### P0-D — Validação no ponto de execução

**Arquivos:** `src/agent_manager.pas`, `src/main.pas`.

- A seleção pode consultar o RES **somente se o PVA associado estiver válido e sincronizado**.
- Antes de `StartPresentation`, revalidar o pacote selecionado e sua versão.
- Seleção obsoleta deve falhar de forma controlada e solicitar nova escolha; nunca executar uma versão alterada por engano.
- Preservar a política atual: conteúdo do RES é dado não confiável para consulta, nunca instrução executável.

### P1 — Experiência do editor e manutenção

**Arquivo:** `src/presentation_editor_ui.pas`.

- Após Salvar, mostrar o resultado por etapa: `PVA salvo`, `PVA validado`, `RES publicado`.
- Se publicação falhar, **não afirmar que o arquivo não foi salvo**: informar a localização do PVA e o motivo da falha do RAG.
- Criar operação de manutenção **Reconstruir índices RES** na biblioteca, aplicando o mesmo extrator a cada PVA.
- Se duas apresentações tiverem o mesmo nome-base, exigir decisão explícita de substituir ou usar nome diferente.

## 6. Matriz de testes de aceitação

| Cenário | Resultado esperado |
| --- | --- |
| Salvar PVA válido com fala e gestos | PVA preserva tags; RES contém fala sem comandos |
| PVA com blocos não chamados no início | RES contém também o texto dos blocos |
| PVA com PPTX, imagens, WAV e MP4 | Mídias continuam dentro do PVA; RES não tenta serializar bytes da mídia |
| Texto com acentos, emoji e UTF-8 | RES preserva texto e é válido em UTF-8 |
| Salvar novamente com conteúdo diferente | RES reflete exclusivamente o novo PVA |
| Alterar só mídia binária mantendo roteiro | Identificador do pacote muda; reprodução revalida a nova versão |
| Alterar PVA mantendo tamanho e timestamp | Índice detecta a mudança por conteúdo ou validação equivalente |
| Apagar ou editar RES manualmente | Monitor reconstrói o RES a partir do PVA |
| RES sem PVA | Não é candidato à seleção automática |
| Copiar PVA inválido ou incompleto | Nenhum RES válido é oferecido; erro diagnosticável |
| Interromper publicação entre as trocas | Entrada não fica disponível com par inconsistente; recuperação posterior |
| Pedido que não se relaciona com biblioteca | Agente responde normalmente sem iniciar apresentação |
| Selecionar pacote e alterá-lo antes de reproduzir | Execução rejeita versão obsoleta |
| Copiar PVA diretamente para RAG | Monitor gera RES sem depender do editor |
| Executar reconstrução global duas vezes | Mesmo resultado; sem mudanças indevidas nos PVA |

### Comandos e fontes de teste existentes

```powershell
python scripts/build_presentations.py --target tests
python tests/run_presentation_rag.py build/presentations
python tests/run_presentation_flow.py
```

Adequar os parâmetros aos requisitos de cada script de teste. Estender principalmente:

- `tests/presentation_rag_tests.lpr`;
- `tests/presentation_rag_agent_tests.lpr`;
- `tests/presentation_flow_editor_tests.lpr`;
- `tests/run_presentation_rag.py`.

Os testes existentes são evidência de cobertura anterior; **não equivalem à homologação dos novos requisitos**.

## 7. Critérios para concluir o projeto

O projeto estará concluído quando:

1. Qualquer RES da biblioteca puder ser reconstruído sem editor, partindo somente do PVA correspondente.
2. O editor não tiver nenhum caminho alternativo que produza RES a partir de texto não empacotado.
3. O monitor corrigir alterações externas e não oferecer pares inválidos/inconsistentes.
4. A seleção e a execução validarem a mesma versão do PVA, considerando seu conteúdo completo.
5. O comportamento com erros de gravação e com atualização simultânea for testado.
6. Compilação e testes automatizados passarem no Windows suportado; o resultado for documentado com versão/commit.
7. A documentação do editor e do RAG refletir exatamente o comportamento implementado.

## 8. Entregáveis

- Código revisado em `src/presentation_rag.pas`, com eventuais ajustes em editor, agente e janela principal.
- Testes automatizados de geração, sincronização, alteração de mídia, recuperação e reprodução.
- Atualização de `Docs/editor-apresentacoes.md` e `Docs/guia-comandos-assistente.md`.
- Relatório de validação com resultados, limitações e versão testada.

## 9. Resumo da regra arquitetural

```text
PVA = ARTEFATO MESTRE, COMPLETO E EXECUTÁVEL
RES = VISÃO TEXTUAL DERIVADA DO PVA PARA BUSCA
RAG = CATALOGA/CONSULTA RES E SELECIONA PVA VÁLIDO
PLAYER = REPRODUZ PVA; JAMAIS EXECUTA RES
```

**Estado desta especificação:** documentação de projeto criada. As melhorias P0/P1 descritas acima **não estão declaradas implementadas** por este documento.
