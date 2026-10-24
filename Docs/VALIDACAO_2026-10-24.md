# Revisão e validação da integração — 24/10/2026

> Registro da revisão anterior ao editor 3D e ao tema MultiCNC. As pendências de gizmos e scrub descritas abaixo foram resolvidas na revisão seguinte; consulte o [guia atual](editor-movimentos.md).

Base sincronizada: `f6ce6249bddc5459fe3adcb2f171819e37a06ea4`, `main`. As correções desta revisão estão no diretório de trabalho; os instaladores históricos não foram reempacotados. Compilação Windows i386-win32, Free Pascal 3.2.2 e Lazarus/Castle já instalados.

## Revisão dos documentos e fontes

- O catálogo atual é versão 2, com 53 receitas calibradas por avatar. As 41 referências externas coexistentes são alternativas: `members` e `profiles` têm prioridade. Isso está explícito em `movimentos-json.md`.
- A implementação externa anterior não compilava devido ao identificador `FileName` herdado de `TCastleScene`. A execução agora compartilha o motor de trajetórias e colisão, com duração do recurso, pausa, velocidade, retorno e loop. A interpolação angular mantém a semântica do arquivo externo.
- O Editor de Movimentos ainda é protótipo. Corrigidos construção da janela, gravação validada com backup, liberação dos diálogos e preservação de opções. A prévia está ligada ao avatar. Gizmos, scrub visual, timeline completa, undo/redo e cadastro de tags permanecem pendentes.
- A proposta PVA/RES identificava uma lacuna real: o hash cobria somente o roteiro. Agora cobre o PVA inteiro e detecta alterações mesmo com tamanho/data preservados. Pacotes inválidos deixam de ser elegíveis, preservando os arquivos do usuário. Melhorias P1 de interface e serialização do par PVA/RES permanecem pendentes; não se declara transação atômica dos dois arquivos.
- Corrigida a reprodução de áudio MCI em caminhos longos, preservando o original e limpando a cópia temporária pertencente ao player.
- Atualizados testes antigos de inventário de clipes, descoberta de pastas de avatar, controles do editor, perfil de colisão isolado e limites de tempo que ainda presumiam movimentos anteriores à versão 2.

## Programas recompilados

Em `build/validation-20261024`: `assistente.exe`, `presentation_editor.exe`, `pva_tool.exe` e `motion_editor.exe`, acompanhados de recursos e DLLs. O último é protótipo e não integra o instalador histórico.

## Evidências

A execução automatizada grava `build/validation-20261024/validation-report/result.json`, com comando, código de saída, duração, logs e SHA-256 dos executáveis. O relatório conserva os testes já aprovados e atualiza os casos repetidos após correções. `source_sha256` identifica os fontes alterados e `resource_sha256` identifica o catálogo, o perfil de colisão e os arquivos externos utilizados nesta revisão.

## Resultado final

- **45 de 45 verificações aprovadas**, incluindo os casos repetidos após correções.
- **1.166 execuções completas**: 53 movimentos × 11 avatares × 2 modos (isolados e em sequência), com proteção de colisão ativa.
- Compilados e validados: Assistente, Editor de Apresentações, ferramenta PVA e protótipo do Editor de Movimentos. A prévia deste último foi acionada pelo próprio botão e concluiu um gesto protegido.
- Aprovados carregamento/renderização dos modelos, anatomia e gestos, catálogo, interpolação, loop/retorno, pausa/velocidade, gravação e backup, áudio real/cancelamento/caminho longo, comandos TCP locais, interface, PVA/ZIP, blocos, mídias e RAG com integridade completa.
- O teste nativo de apresentação abre vários avatares e restaura a configuração original; seu prazo externo passou a 120 s para comportar a sequência medida, preservando as asserções internas. O teste do editor usa relatório em arquivo por ser um aplicativo gráfico sem console.

Os quatro executáveis, recursos, DLLs, licenças, manifesto e cópia deste relatório ficam em `build/programas-validados-20261024`. Os instaladores publicados 0.212/0.213 permanecem históricos e não contêm estas novas correções. As alterações dos fontes e documentos permanecem locais, sem novo envio ao GitHub.

## Reproduzir

```powershell
python scripts/build_presentations.py --release --out build/validation-20261024
python scripts/build_presentations.py --target tests --out build/validation-20261024
python scripts/validate_assistente.py --build build/validation-20261024 --native --all-movements
```

A suíte usa diretórios de configuração isolados e provedores HTTP locais. As janelas automáticas devem permanecer na sessão interativa para que o renderer seja atualizado. A execução nativa de apresentações usa `--without-office`.

## Limites

Não foram homologados microfone/STT físico, câmera, Kinect, conversa com credenciais reais, Office/PowerPoint instalado, Win64 ou outros sistemas operacionais. Testes de fala usam WAV silencioso e reprodução Windows real. A validação de cápsulas de colisão não equivale à simulação física completa das superfícies do avatar. As 41 alternativas externas passaram por validação de formato; sua reprodução como substitutas dos percursos calibrados em todos os avatares não foi homologada. Nenhum resultado de teste declara concluídas as funcionalidades ainda propostas nos documentos.

## Distribuição posterior

O [instalador 0.214](INSTALACAO_0214.md) reúne estas correções e o protótipo com prévia em um pacote instalável. Os instaladores anteriores continuam históricos. A validação específica da instalação é registrada no relatório da versão 0.214.
