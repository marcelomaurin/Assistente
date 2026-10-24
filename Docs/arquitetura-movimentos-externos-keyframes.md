# Arquitetura proposta — movimentos externos por quadros-chave (v2)

**Status:** proposta técnica para revisão; nenhuma mudança de execução está autorizada por este documento.  
**Projeto:** Assistente / Editor de Apresentações (Lazarus/Free Pascal + Castle Game Engine).  
**Objetivo:** permitir que a IA crie animações reutilizáveis, externas ao executável, disparadas pelas **mesmas tags** do sistema atual, sem Blender e sem recompilação.

## 1. Decisões e invariantes

1. **A tag continua sendo o gatilho.** Ex.: `[aceno]` é reconhecida pelo parser atual, consultada no catálogo e executada pelo avatar. Não exigir uma nova sintaxe `[movimento=...]`.
2. **Não criar um catálogo concorrente.** Preservar `AVATARES/movimentos.json`, o módulo `src/movement_catalog.pas`, os IDs, tags, aliases, modos, clipes e poses existentes.
3. Adicionar a cada movimento, opcionalmente, `animation_file`, apontando para um arquivo de animação externo. O catálogo continua indexando os movimentos; o arquivo externo descreve sua trajetória temporal.
4. Manter `clip`, `talking_clip` e `joints` legados sem alteração de significado. Um movimento novo usa **ou** `animation_file` **ou** a forma legada; rejeitar combinações ambíguas na versão 2.
5. A IA pode escolher uma tag já cadastrada ou produzir uma definição de animação que, após validação e confirmação de cadastro, passa a ser invocada por uma tag. Não executar JSON arbitrário sem validação.
6. O Castle continua sendo o renderizador; o runtime Free Pascal executa interpolação de poses em ossos já existentes no rig. Não depender de morph targets ou de importação de animações glTF que a revisão Castle fixada não garanta.
7. Não reescrever PVA/RES: as tags existentes devem continuar sendo aceitas. O editor e o Assistente devem usar a mesma biblioteca.

## 2. Estado real do repositório e lacuna

- `AVATARES/movimentos.json` já contém catálogo `version: 1`, com movimentos e aliases; `[aceno]` mapeia para `clip: "wave"`.
- `src/movement_catalog.pas` carrega, valida e recarrega o catálogo; `TMovementDefinition` possui `Clip`, `TalkingClip`, `Duration`, `Transition` e `Joints`.
- `Docs/movimentos-json.md` documenta movimentos por clipe existente ou lista de articulações. Em `joints`, cada osso aparece no máximo uma vez, com eixo, ângulo e duração: **não há trajetória com vários quadros por osso**.
- `src/professor_view.pas` resolve `FindMovement`, escolhe clipe, verifica ossos e chama `TPresentationScene.ExecuteJoint` para cada articulação.
- `src/presentation_joints.pas` implementa transição de ângulo por articulação, sem fila completa de quadros-chave.
- `src/reception_core.pas` calcula espera entre movimentos a partir de `Duration`, `Transition` e durações dos `Joints`.
- A documentação do projeto registra limitações do Castle fixado para morph targets/animações glTF; o projeto já utiliza animações esqueléticas e articulações. Portanto, a proposta **não presume** suporte novo do Castle.
- **Atenção:** a documentação e os fontes foram inspecionados estaticamente; compilação, execução e cobertura de testes ainda são pendentes.

## 3. Organização dos recursos

Preservar:

```text
AVATARES/
  movimentos.json              # catálogo compartilhado já existente
  movimentos/                  # novo subdiretório de arquivos, NÃO novo catálogo
    aceno_personalizado.json
    apontar_grafico.json
```

O nome `AVATARES/movimentos/` é **proposta de organização**, não afirmação de que essa pasta já exista no repositório. A instalação pode usar outro diretório de recursos configurado, mas deve ter resolução previsível e independente do diretório de trabalho do processo.

Exemplo de entrada adicionada ao array `movements` do catálogo:

```json
{
  "id": "aceno_personalizado",
  "tag": "aceno personalizado",
  "title": "Aceno personalizado",
  "category": "Mãos",
  "description": "Acena com a mão direita em três oscilações.",
  "mode": "gesture",
  "animation_file": "movimentos/aceno_personalizado.json",
  "duration_ms": 1800,
  "transition_ms": 250
}
```

A tag de disparo será `[aceno personalizado]`, tal como `[aceno]` continua chamando o clipe legado. A referência externa é **relativa à pasta AVATARES**; nunca permitir caminho absoluto, `..`, links simbólicos que escapem da raiz ou URL remota.

## 4. Formato proposto para o arquivo externo

A estrutura abaixo é um **formato específico do Assistente**, inspirado em canais/quadros-chave de glTF, mas **não é um arquivo glTF 2.0**. Não afirmar compatibilidade direta com leitores glTF.

```json
{
  "format": "assistente-motion",
  "version": 1,
  "name": "Aceno personalizado",
  "duration_ms": 1800,
  "loop": false,
  "return_to_base": true,
  "tracks": [
    {
      "bone": "upper_arm.R",
      "axis": "z",
      "keyframes": [
        {"time_ms": 0, "angle": 0},
        {"time_ms": 350, "angle": 38},
        {"time_ms": 1500, "angle": 38},
        {"time_ms": 1800, "angle": 0}
      ]
    },
    {
      "bone": "wrist.R",
      "axis": "y",
      "keyframes": [
        {"time_ms": 0, "angle": 0},
        {"time_ms": 500, "angle": -18},
        {"time_ms": 750, "angle": 18},
        {"time_ms": 1000, "angle": -18},
        {"time_ms": 1250, "angle": 18},
        {"time_ms": 1500, "angle": 0},
        {"time_ms": 1800, "angle": 0}
      ]
    }
  ],
  "interpolation": "smoothstep"
}
```

**Importante:** os nomes dos ossos e eixos acima são ilustrativos e devem ser confrontados com o rig real de cada avatar antes de serem usados como exemplo executável. O loader não deve criar ossos fictícios nem presumir correspondência entre avatares. Os ângulos são valores relativos à pose-base definida para a animação; definir explicitamente a convenção na implementação para evitar acumulação de rotações a cada ciclo.

### Regras de validação propostas

- `format` e `version` obrigatórios; limites documentados de tamanho de arquivo, duração, quantidade de trilhas e quadros-chave.
- `time_ms` inteiro, não negativo, **estritamente crescente** por trilha e dentro de `duration_ms`; ao menos dois quadros por trilha.
- `angle` finito, com limites permitidos por osso e eixo; usar `JointAngleLimit` e estender validação por rig quando necessário.
- Eixos `x`, `y`, `z`; permitir várias trilhas no mesmo osso **somente em eixos distintos** e definir ordem/composição de rotações, ou inicialmente rejeitar mais de um eixo por osso até existir composição correta.
- Interpolação `linear` e `smoothstep` na primeira versão; sem extrapolação fora da duração.
- Não permitir alterar a mandíbula durante fala, salvo política explícita de prioridade; preservar proteção dos canais faciais.
- Falha de validação **não pode substituir o catálogo ou movimento ativo por um estado parcial**. Mensagem de erro com arquivo, campo e motivo.
- Proteção contra arquivos alterados durante leitura: parse completo em objeto temporário, validação, depois troca atômica em memória.

## 5. Linha do tempo e execução

Fluxo: texto/roteiro → parser de tags existente → `FindMovement` → `animation_file` ou execução legada → loader/cache → validação do rig → player de quadros-chave → atualização dos ossos no ciclo de renderização.

- Cada trilha calcula o valor no instante `t` por interpolação entre quadros vizinhos; várias trilhas atualizam juntas no mesmo frame. Não fazer `Sleep` no thread da interface.
- Utilizar relógio monotônico e **tempo de animação acumulado**; pausa congela o relógio, retomada continua do mesmo instante, cancelamento interrompe imediatamente.
- Transições de entrada/saída devem usar `transition_ms` e preservar a pose-base. `return_to_base` define retorno, sem saltos bruscos.
- A política inicial para dois gestos concorrentes que disputem o mesmo osso será **substituir o anterior com transição suave**; canais independentes podem coexistir se o controlador conseguir compor corretamente. Não somar ângulos indiscriminadamente.
- `loop: true` exige limite externo de execução ou cancelamento explícito; apresentações não podem ficar bloqueadas indefinidamente.
- Duração efetiva é derivada do recurso validado; `duration_ms` do catálogo pode ser usado para metadados/compatibilidade, mas a execução e espera não podem divergir. Definir e testar a precedência; proposta: rejeitar durações conflitantes, ou atualizar a duração efetiva em memória a partir do recurso.
- Em modo `pose`, manter o último quadro até comando posterior; em `gesture`, concluir e retornar conforme configuração. Não alterar sem necessidade a semântica legada.

## 6. Plano de implementação, em ordem

### Etapa A — formato e testes de parser (sem alterar execução)

1. Criar `src/movement_animation.pas` com tipos de trilha/quadro-chave, leitor, validação e interpolador puro testável.
2. Definir constantes de limites e mensagens de erro; testar tempos inválidos, ângulos fora do limite, ossos desconhecidos, arquivo ausente, travessia de caminho e JSON malformado.
3. Acrescentar testes determinísticos de interpolação em tempos exatos, intermediários, início e fim; provar múltiplos ossos em paralelo.

### Etapa B — catálogo e compatibilidade

4. Acrescentar `AnimationFile` a `TMovementDefinition` em `src/movement_catalog.pas`; manter leitura de `version: 1` para catálogos atuais. **Não elevar a versão do catálogo sem necessidade**; novo campo opcional compatível.
5. Resolver arquivo relativo à raiz `AVATARES`, validar extensão e segurança do caminho; carregar o recurso sem aceitar comandos de sistema.
6. Manter `FindMovement`, `MovementInstructions`, tags e aliases inalterados; preservar os modos legados e comportamento de clipes/poses.
7. Recarregamento do catálogo deve invalidar corretamente o cache de recursos externos; detectar mudanças no arquivo referenciado, não só no catálogo.

### Etapa C — player esquelético

8. Evoluir `src/presentation_joints.pas` para atualizar múltiplas trilhas por tempo de reprodução; não sobrescrever uma trilha no meio de sua sequência.
9. Integrar em `src/professor_view.pas` por `ExecuteMovement`; validar ossos do avatar antes de iniciar; preservar `ExecuteJoint` legado.
10. Conectar ao `TimerTick`/ciclo apropriado de renderização, pausa, retomada, reset e troca de avatar. Impedir referências a nós de cena destruídos.
11. Conciliar reprodução de clipes existentes, gestos externos, fala, sorriso e piscadas; estabelecer prioridade e comportamento de retorno.

### Etapa D — editor, apresentação e IA

12. Ajustar `src/reception_core.pas` para aguardar a **duração efetiva** de animação externa entre tags de movimento, sem bloquear áudio/mídia e respeitando cancelamento.
13. Editor: biblioteca continua lendo o catálogo compartilhado; adicionar indicação de recurso externo, validação e recarregamento, mantendo inserção da tag atual.
14. IA: primeiro selecionar movimentos cadastrados; depois habilitar geração de arquivos no esquema versionado, em área temporária, com validação rigorosa, pré-visualização e cadastro explícito. Não gravar diretamente sobre movimentos personalizados existentes.
15. Atualizar `Docs/movimentos-json.md`, documentação de tags, empacotamento e exemplos. Garantir preservação de arquivos personalizados em atualização/desinstalação, tal como o instalador já trata `AVATARES/movimentos.json`.

## 7. Testes de aceitação obrigatórios

1. Todos os movimentos antigos continuam funcionando, incluindo `[aceno]`, clipes, `pose`, `reset`, `joints` e aliases.
2. Adicionar um JSON externo e uma entrada no catálogo, recarregar e executar **sem recompilar**.
3. Um movimento contém ao menos três articulações, cada uma com quatro ou mais quadros-chave; observar movimento coordenado.
4. Dois movimentos consecutivos não se sobrepõem incorretamente; o último termina antes de `[FIM]`.
5. Pausar no meio, retomar e cancelar não causam salto, congelamento permanente nem movimento residual.
6. Trocar de avatar com movimento ativo não acessa ponteiros de ossos inválidos; falta de osso gera erro amigável.
7. Fala simultânea não perde sincronização da mandíbula; expressões faciais preservadas.
8. Caminhos inseguros, arquivo corrompido e valores extremos são rejeitados; o catálogo anterior continua utilizável.
9. Testes de parser e player executados no Free Pascal; compilação do Assistente e editor; validação visual real no Castle fixado.

## 8. Critérios para não avançar às cegas

- Primeiro aprovar este desenho e confirmar os nomes/eixos de ossos dos avatares distribuídos.
- Só depois alterar o runtime, mantendo testes e reversibilidade.
- **Não declarar a implementação concluída** sem compilar e executar testes; a documentação isolada não é implementação.
- Publicar código em branch/PR para revisão antes de mesclar em `main`, salvo orientação explícita em contrário.

## 9. Alternativas consideradas

- **glTF/GLB:** formato de intercâmbio sólido, porém geração direta pela IA é mais complexa e o Castle fixado possui limitações documentadas; pode ser importado futuramente.
- **BVH:** adequado a captura de movimento, mas requer mapeamento/retargeting para os ossos dos avatares.
- **JSON de ângulo único:** já existe no catálogo, mas não representa sequências complexas.
- **JSON externo de quadros-chave:** escolhido para geração por IA, revisão humana, versionamento, validação, hot reload e integração mínima com a arquitetura atual.

**Resultado esperado:** a tag dispara; `AVATARES/movimentos.json` identifica; o arquivo externo descreve os quadros-chave; o player esquelético executa. Nenhuma ferramenta Blender é necessária.
