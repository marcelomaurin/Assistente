# Instalação 0.217

Execute `bin/setup_assistente_0217.exe`. A instalação é por usuário, em `%LOCALAPPDATA%\Programs\Assistente`, e atualiza a 0.216 mantendo configurações, histórico, avatares pessoais, catálogo de movimentos editado e documentos do RAG.

## Novidades

- **Configurações > Exportar... / Importar...**: gera um arquivo `*.assistente-config.json` com a configuração do Assistente e aplica esse arquivo em outra instalação, com ou sem as credenciais. Também é possível aplicar ao iniciar: `assistente.exe --importar-config=<arquivo>`.
- **Configurações > Documentos (RAG)**: adicionar, listar, remover e abrir a pasta dos documentos que a IA usa como referência. Além das apresentações `.pva`, a biblioteca aceita documentos de consulta `.txt`, `.md`, `.csv`, `.json` e `.rag`.
- A IA passa a usar os documentos da biblioteca como referência também nas respostas comuns (opção na mesma aba, ligada por padrão), não só nas perguntas durante apresentações.
- Avatar **businesswoman** (importado do Tripo3D): removidas as trilhas de animação sem destino que impediam a abertura do modelo em alguns visualizadores glTF. Malha, texturas, clipes e movimentos não mudaram.
- Correção: um valor de configuração que contivesse o nome de outra chave (por exemplo `POSX:`) podia ser lido como essa chave ao abrir o programa.

Detalhes em [arquivo de configuração e documentos do RAG](configuracao-arquivo-e-rag.md). Os recursos da 0.216 (Perguntar, Menu, Encerrar vídeo) continuam iguais; veja [INSTALACAO_0216.md](INSTALACAO_0216.md).

## Ferramentas incluídas

Assistente, Editor de Tags/Apresentações, ferramenta PVA, prévia do Editor de Movimentos e Criador Avatar com Python isolado.

## Verificação

Os hashes de cada arquivo estão em `bin/setup_assistente_0217.manifest.json` e o resultado dos testes em `bin/setup_assistente_0217.validacao.json`.

Este pacote foi compilado com o compilador cruzado Free Pascal 3.2.2 (i386-win32) e verificado no Wine 9: instalação limpa, atualização a partir do instalador 0.216 real, preservação de catálogo editado e de avatar do usuário, gerador do Criador Avatar instalado e os testes de biblioteca RAG, seleção de apresentação pelo agente e arquivo de configuração. A suíte nativa do Windows (`tests/check_installer.py`) não foi executada neste ambiente; rode-a no Windows antes de distribuir.
