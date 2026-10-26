# Bugs e pendências — Assistente

## Revisão de 26/10/2026

- Projeto: `marcelomaurin/Assistente`.
- Branch analisada: `main`.
- Versão de referência: **0.214**.
- Commit analisado: [8fb81db7a3fc535e57bd3a19659b3b39e03bae25](https://github.com/marcelomaurin/Assistente/commit/8fb81db7a3fc535e57bd3a19659b3b39e03bae25).
- Método: leitura dos fontes, workflows, logs do GitHub Actions e relatórios publicados. O aplicativo Windows e os testes nativos não foram executados novamente nesta revisão.
- Situação: diagnóstico original preservado. **BUG-03 e BUG-04 receberam correção em 26/10/2026**, conforme atualização abaixo. Os problemas do agente, as pendências do editor e a homologação física continuam abertos.

P1 indica prioridade para a confiabilidade do fluxo principal ou da entrega. P2 indica complemento funcional. Pendências de implementação e lacunas de validação estão identificadas separadamente dos bugs.

| ID | Prioridade | Tipo | Item |
| --- | --- | --- | --- |
| BUG-01 | P1 | Código | Leitura automática de arquivo sem argumento de caminho |
| BUG-02 | P1 | Código | Etapa marcada como concluída mesmo quando a ferramenta falha |
| BUG-03 | P1 | Compilação | Workflow Windows instala ambiente de 64 bits e exige compilador de 32 bits |
| BUG-04 | P1 | Automação | Workflow Windows não valida os envios diretos à main |
| PEND-01 | P2 | Implementação | Editor de movimentos sem desfazer/refazer e exclusão de quadros |
| PEND-02 | P2 | Implementação | Animação salva ainda exige integração manual ao catálogo de tags |
| VAL-01 | P1 | Validação | Fluxo completo com dispositivos e provedores reais sem homologação na suíte mais recente |

### BUG-01 — Leitura automática de arquivo sem argumento de caminho

**Evidência:** em [agent_manager.pas](../src/agent_manager.pas), `TAssistantPlanner.CreatePlan` adiciona a etapa `file.read` ao detectar “arquivo” ou “codigo”. Em `TAgentWorkerThread.Execute`, a chamada atribui apenas `CallObj.ToolName`, sem preencher `Arguments.path`. `ToolFileRead` exige esse caminho e retorna “Arquivo invalido” quando ele está vazio.

**Impacto:** o fluxo automático cria uma etapa de inspeção que não consegue ler o arquivo pretendido.

**Correção proposta:** transportar os argumentos necessários no plano e preencher a chamada da ferramenta; solicitar ou resolver o caminho quando faltar informação.

**Critério de aceite:** uma solicitação com arquivo existente entrega seu conteúdo à etapa seguinte; caminho ausente ou inválido produz uma falha explícita, sem simular leitura bem-sucedida.

### BUG-02 — Etapa concluída mesmo após falha de ferramenta

**Evidência:** em [agent_manager.pas](../src/agent_manager.pas), `TAgentWorkerThread.Execute` coloca `ResultObj.ErrorText` no resultado quando `ResultObj.Success=False`, mas em seguida chama `UpdateCurrentStepStatus('done', R)` e publica o status `done`. A síntese pode continuar e o sucesso final depende de haver texto de resposta.

**Impacto:** uma falha operacional pode aparecer no planejamento como trabalho concluído. Isso enfraquece a confiabilidade da resposta final.

**Correção proposta:** propagar sucesso e falha de cada operação para o estado da etapa e para o resultado geral; definir quando interromper, tentar novamente ou informar conclusão parcial.

**Critério de aceite:** uma ferramenta que retorna erro não recebe status de sucesso, e a resposta final informa a limitação correspondente.

### BUG-03 — Incompatibilidade de arquitetura no workflow Windows

**Evidência:** o [workflow professor-windows-build.yml](../.github/workflows/professor-windows-build.yml) instala Lazarus via Chocolatey e exige `FPC 3.2.2 i386-win32`. Na [execução 40086252459](https://github.com/marcelomaurin/Assistente/actions/runs/40086252459), de 24/10/2026, foi instalado Lazarus de 64 bits. O passo “Inspect installed compiler” falhou com `FPC 3.2.2 i386-win32 not found in Lazarus installation`; o passo de compilação foi ignorado.

**Impacto:** essa execução não comprova que o código compila nem que contém erro de compilação, pois o compilador solicitado não chegou a ser executado.

**Correção proposta:** provisionar explicitamente o compilador Win32 compatível com o alvo e as dependências, ou preparar e validar um alvo Win64 completo.

**Critério de aceite:** o workflow encontra o compilador da arquitetura escolhida, executa a compilação e publica evidências do resultado.

**Atualização de 26/10/2026 — corrigido para Win64:** o workflow usa Lazarus 3.0/FPC 3.2.2 de 64 bits, encontra o compilador instalado, obtém as revisões fixadas de CHATGPT e Castle e guarda o toolchain em cache. A [execução 40327124951](https://github.com/marcelomaurin/Assistente/actions/runs/40327124951) compilou o Assistente completo e aprovou os três programas de regressão de menus/documentos/PDF. Isso valida a compilação e esses testes; não substitui a homologação de dispositivos e provedores reais de VAL-01.

### BUG-04 — Envios diretos à main sem validação automática do build Windows

**Evidência:** em [professor-windows-build.yml](../.github/workflows/professor-windows-build.yml), o gatilho `push` contempla apenas `feature/external-motion-keyframes`. Há gatilhos de pull request para `main` e execução manual. A consulta ao Actions não retornou execuções associadas à branch `main` durante esta revisão.

**Impacto:** uma alteração enviada diretamente à main pode ficar sem compilação Windows automática correspondente.

**Correção proposta:** habilitar o gatilho de envio à main e preparar todas as dependências no runner, inclusive a revisão fixada da biblioteca CHATGPT.

**Critério de aceite:** um envio à main inicia a validação do commit enviado em ambiente reproduzível.

**Atualização de 26/10/2026 — corrigido no workflow:** o gatilho `push` agora inclui `main`; o ambiente obtém as dependências fixadas antes de compilar. A execução Win64 e os testes foram aprovados na branch de validação antes da publicação. Cada novo envio à main agenda a mesma verificação.

### PEND-01 — Recursos de edição de movimentos ainda incompletos

**Evidência:** [guia atual do editor](editor-movimentos.md) e [validação do editor 3D](VALIDACAO_EDITOR_3D_2026-10-24.md).

O editor já oferece seleção de membros, rotação XYZ, gravação de poses, navegação temporal e reprodução protegida. Permanecem pendentes desfazer/refazer, exclusão de quadros, curvas e trilhas visuais e seleção de outro avatar pela interface.

**Impacto:** corrigir poses ou experimentar movimentos exige mais operações manuais.

**Critério de aceite prioritário:** desfazer/refazer alterações e excluir quadros preservando a validade do JSON e a reprodução.

### PEND-02 — Cadastro de tags e integração da animação salva

**Evidência:** [editor-movimentos.md](editor-movimentos.md). Salvar um JSON não cadastra automaticamente uma tag. As 53 receitas internas calibradas mantêm prioridade sobre os arquivos externos de referência.

**Impacto:** criar e salvar uma animação no editor ainda não completa, pela interface, o processo de disponibilizá-la como novo comando na conversa.

**Correção proposta:** implementar cadastro e associação de tags, com regras claras de prioridade e preservação dos movimentos existentes.

**Critério de aceite:** criar um movimento, salvar, associar uma tag e executá-la no Assistente sem editar manualmente o catálogo.

### VAL-01 — Homologação do fluxo real

**Evidência:** [validação geral de 24/10/2026](VALIDACAO_2026-10-24.md), [validação do editor 3D](VALIDACAO_EDITOR_3D_2026-10-24.md) e [relatório do instalador 0.214](../bin/setup_assistente_0214.validacao.json).

Os documentos registram verificações locais aprovadas. A suíte mais recente deixa fora do escopo microfone/STT físico, Kinect, câmera e provedores com credenciais reais; também não homologa o aplicativo completo em Win64 ou Linux. Existem evidências anteriores de PowerPoint na sessão do usuário, mas Office não foi incluído na suíte mais recente.

**Natureza:** lacuna de validação, não defeito comprovado desses recursos.

**Critério de aceite:** registrar uma sessão com microfone, transcrição, consulta real à IA, reprodução de voz, avatar e retomada da escuta; validar cancelamento e recuperação de falhas. Validar câmera/Kinect nos equipamentos disponíveis, documentando separadamente os resultados.

## Ordem sugerida

1. Corrigir argumentos e propagação de falhas no agente: BUG-01 e BUG-02.
2. Manter a compilação automática da main: BUG-03 e BUG-04 corrigidos para o alvo Win64; acompanhar o Actions de cada entrega.
3. Homologar a conversa completa no computador de uso: VAL-01.
4. Completar os recursos de autoria e integração de movimentos: PEND-01 e PEND-02.

## Entrega de menus — 26/10/2026

Implementados os menus suspensos de abrir/fechar arquivo, imprimir apresentação em PDF, pesquisar texto e Sobre, sem botão extra de abertura no cabeçalho. A compilação completa Win64 e os testes de regressão passaram. Consulte o [relatório da entrega](MENUS_PDF_2026-10-26.md) e o [manual de uso](ManualUsuario/README.md#menus-suspensos-arquivos-pesquisa-e-pdf). O instalador 0.214 anterior não foi substituído por essa alteração.

