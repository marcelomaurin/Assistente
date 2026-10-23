# Assistente 0.210 — instalador Windows

Arquivo: `bin/setup_assistente_0210.exe`.

## Novidades

- Layout atualizado do Assistente e do Editor de Apresentações, seguindo a identidade visual Maurinsoft usada no MNote2.
- Biblioteca de movimentos com busca, inserção de tags e recarregamento no editor; seleção e execução no Assistente.
- Catálogo compartilhado `AVATARES/movimentos.json`, incluindo tags, aliases, clipes, durações e poses por articulações. Novos movimentos podem ser cadastrados sem recompilar.
- Correção da reprodução do WAV retornado pela OpenAI: os tamanhos indefinidos do cabeçalho de streaming são finalizados antes de abrir o áudio no Windows, preservando PCM e metadados.
- Os 11 avatares atualizados, ferramenta PVA, bibliotecas HTTPS, exemplos, documentação e licenças.

## Instalação

Execute o setup. A pasta padrão é `%LOCALAPPDATA%\Programs\Assistente`, por usuário e sem exigir administrador. O menu Iniciar recebe atalhos para o Assistente, o editor e a documentação; os atalhos na área de trabalho são opcionais.

A atualização usa a mesma identificação das versões anteriores. O pacote não contém chaves, histórico nem configurações pessoais. Um catálogo `AVATARES/movimentos.json` já existente é preservado na reinstalação e na desinstalação, para manter movimentos personalizados. Uma instalação nova recebe o catálogo padrão desta versão.

Consulte [Configurar movimentos por JSON](movimentos-json.md) e o [guia de comandos](guia-comandos-assistente.md). A síntese OpenAI continua usando a chave e a voz configuradas pelo usuário.

## Compilação e validação

```powershell
python scripts/build_presentations.py --release --compiler C:/lazarus/fpc/3.2.2/bin/i386-win32/fpc.exe --out build/presentations-0210
.\scripts\build_installer.ps1 -Version 0.210 -BuildCode 0210 -Executable build/presentations-0210/assistente.exe -Editor build/presentations-0210/presentation_editor.exe -Tool build/presentations-0210/pva_tool.exe
python tests/check_installer.py --build-code 0210 --version 0.210 --no-ui
```

O manifesto `bin/setup_assistente_0210.manifest.json` registra os hashes SHA-256 do instalador e de todos os arquivos empacotados. O relatório `bin/setup_assistente_0210.validacao.json` registra os testes do setup real em pasta isolada: instalação, integridade, avatares, runtime HTTPS, ferramenta PVA, reinstalação e desinstalação, com preservação dos dados de teste e sem alterar o registro da instalação habitual.

A opção `--no-ui` não abre as janelas dos aplicativos nem usa câmera, microfone ou provedores externos; essa restrição é registrada no relatório. Os testes de áudio e do catálogo compartilhado são executados separadamente durante o desenvolvimento.

## Correção dos comandos de movimento

O pacote revisado inclui os 65 clipes de cada avatar, cobrindo todos os
movimentos do catálogo. Foram adicionados os 18 clipes anteriormente ausentes,
incluindo braços cruzados. `[cruzar os braços]` e `[cruzar bracos]` são
equivalentes. Sequências de tags e o último gesto respeitam sua duração,
incluindo pausa e cancelamento. Entradas contendo apenas tags no chat são
executadas diretamente. O empacotamento rejeita movimentos sem animação.
