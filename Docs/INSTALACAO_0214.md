# Assistente 0.214 — Editor de Movimentos com prévia

O [instalador 0.214](../bin/setup_assistente_0214.exe) inclui:

- Assistente atualizado e **Editor de Tags / Apresentações obrigatório**, instalado mesmo sem selecionar atalhos opcionais.
- **Editor de Movimentos (prévia)**, com seleção de membros no avatar, anéis de rotação XYZ, vistas CAD, navegação de câmera e padrão visual do MultiCNC, linha do tempo, gravação validada com backup e reprodução protegida.
- Ferramenta PVA, onze avatares, catálogo com 53 movimentos, 41 arquivos externos de referência e os guias.
- Correções pós-integração em animações externas, pausa/velocidade/retorno, áudio em caminhos longos e integridade do RAG sobre o pacote PVA completo.

## Instalar e abrir a prévia

Execute o instalador normalmente. A edição de tags é realizada pelo Editor de Apresentações (`presentation_editor.exe`), que permanece incluído em toda instalação, atualização e reinstalação. O menu Iniciar inclui **Editor de Tags do Assistente** e mantém o atalho **Editor de Apresentações do Assistente** para a mesma ferramenta. As opções de atalhos na área de trabalho não controlam a instalação do programa. O menu Iniciar recebe o atalho **Editor de Movimentos do Assistente (prévia)** e seu guia. Um atalho na área de trabalho e a abertura da prévia ao concluir a instalação são opcionais. Os três aplicativos usam a mesma pasta `AVATARES`.

A instalação padrão continua por usuário em `%LOCALAPPDATA%/Programs/Assistente`, com o mesmo identificador de aplicativo das versões anteriores. Não é necessário desinstalar a 0.213 antes de atualizar. Arquivos de configuração e histórico são preservados.

Catálogos padrão intactos de 0.210, 0.211, 0.212 e 0.213 são atualizados. Catálogos personalizados permanecem intactos. O perfil de colisão intacto de 0.212 também é atualizado. Os arquivos JSON externos já existentes são mantidos na reinstalação e na desinstalação, para preservar o trabalho feito no editor. Novos arquivos padrão são instalados somente quando ainda não existem.

Consulte o [guia do Editor de Movimentos](editor-movimentos.md) para abrir um JSON e usar **Reproduzir movimento**. A versão distribuída é uma prévia: IK, timeline com trilhas/curvas, undo/redo, exclusão de quadros, IA e cadastro automático de tags continuam pendentes. O leitor reconhece arquivos v1 e poses XYZ no formato v2.

## Build e validação

```powershell
python scripts/build_presentations.py --release --out build/presentations-0214
./scripts/build_installer.ps1 -Version 0.214 -BuildCode 0214
python tests/check_installer.py --build-code 0214 --version 0.214 --no-ui
```

A validação do instalador ocorre em uma pasta isolada sob `build`, sem registrar outra instalação ou criar atalhos no ambiente real. Confere todos os arquivos por SHA-256, upgrade a partir do instalador real 0.213, DLLs SSL, ferramenta PVA, movimentos instalados, execução da prévia e preservação dos arquivos editados durante reinstalação/desinstalação. `--no-ui` desativa a automação externa das janelas; a própria prévia executa seu teste nativo de abertura e reprodução.

Os hashes e o inventário estão no [manifesto](../bin/setup_assistente_0214.manifest.json), e o resultado no [relatório de instalação](../bin/setup_assistente_0214.validacao.json). A base funcional passou pelas [45 verificações e 1.166 execuções de movimentos](VALIDACAO_2026-10-24.md). Hardware físico, credenciais reais e Office não foram homologados por essa suíte.

## Revisão da prévia 3D

O pacote recompilado com a navegação e o visual do MultiCNC está em `build/presentations-0214-cad`. A prévia faz verificações nativas de seleção na tela, arraste dos anéis, hierarquia do esqueleto, gravação/reabertura XYZ, scrub, colisões e sete vistas de câmera. O teste captura a interface e o avatar renderizado para inspeção visual.
