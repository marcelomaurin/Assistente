# Instalação 0.218

Execute `bin/setup_assistente_0218.exe`. A instalação é por usuário, em `%LOCALAPPDATA%\Programs\Assistente`, e atualiza a 0.217 mantendo configurações, histórico, avatares pessoais, catálogo de movimentos editado e documentos do RAG.

## Novidades

### Modo apresentação

- A área da direita vira um palco escuro durante a apresentação.
- **Barra de blocos** no topo, com o título da apresentação e o bloco atual destacado.
- **Legenda** abaixo da mídia, com o trecho que o avatar está falando.
- **Barra de controles** com **Pausar (P)**, **Menu**, **Perguntar** e, com o roteiro pausado, **Continuar**. Menu e Perguntar saíram do cabeçalho.
- O painel **Perguntas da plateia** fica ao lado da mídia.

### Coluna da esquerda e menu Apresentação

- Lista de **Assuntos**, os blocos da apresentação, acima do avatar. Clique ou Enter abre o bloco. O bloco atual fica selecionado.
- Divisória arrastável para ajustar a largura da coluna da esquerda.
- Menu **Apresentação** com **Carregar apresentação (.pva)**, **Iniciar do começo** e **Assuntos**. Carregar abre a apresentação sem iniciá-la.

### Configurações

- As abas foram substituídas por uma lista lateral agrupada em **Essencial**, **Apresentações** e **Avançado**.
- Cada seção tem um ponto de status: verde (último teste aprovado), vermelho (falhou) ou cinza (recurso desligado).
- O resultado do último teste aparece no topo da seção.
- Um aviso **Alterações não salvas** aparece ao lado de Salvar.

Os recursos da 0.217 (exportar/importar configuração e documentos do RAG) continuam iguais; veja [INSTALACAO_0217.md](INSTALACAO_0217.md). Detalhes das perguntas em [perguntas-apresentacao.md](perguntas-apresentacao.md).

## Ferramentas incluídas

Assistente, Editor de Tags/Apresentações, ferramenta PVA, prévia do Editor de Movimentos e Criador Avatar com Python isolado.

## Verificação

Os hashes de cada arquivo estão em `bin/setup_assistente_0218.manifest.json` e o resultado dos testes em `bin/setup_assistente_0218.validacao.json`.
