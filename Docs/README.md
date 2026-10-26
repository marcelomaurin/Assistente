# Documentação do Assistente

O Assistente é uma aplicação Windows em Lazarus/Free Pascal para conversar com IA por texto e voz e apresentar respostas com um professor virtual 3D.

| Guia | Conteúdo |
| --- | --- |
| [Projeto e funcionalidades](Projeto/README.md) | Arquitetura, mapa das fontes, recursos, versões, dependências, compilação e testes |
| [Integração por DLL](DLL/README.md) | DLL Win32/Win64, funções exportadas, buffers, exemplos e erros |
| [Protocolo de comunicação socket](Socket/README.md) | Autenticação, lista de IPs, JSON, ações, respostas e limites |
| [Instalador 0.217](INSTALACAO_0217.md) | Arquivo de configuração (exportar/importar) e documentos do RAG em Configurações |
| [Arquivo de configuração e RAG](configuracao-arquivo-e-rag.md) | Gerar e aplicar a configuração; adicionar documentos que a IA consulta |
| [Instalador 0.216](INSTALACAO_0216.md) | Perguntar, Menu, Continuar e Encerrar vídeo nas apresentações |
| [Instalador 0.215](INSTALACAO_0215.md) | Criador Avatar, importação MakeHuman/Avaturn/Tripo3D e 18 avatares |
| [Criador Avatar](criador-avatar.md) | Criar, importar e gerar avatares para o Assistente |
| [Instalador 0.214](INSTALACAO_0214.md) | Assistente, apresentações e prévia do Editor de Movimentos |
| [Guia de comandos](guia-comandos-assistente.md) | Blocos, eventos futuros, avatar, voz, mídias e comandos de entrada |
| [Manual do usuário](ManualUsuario/README.md) | Instalação, menus de arquivos, PDF, pesquisa, conversa, voz, avatar, vídeo e integração |
| [Menus e PDF — 26/10/2026](MENUS_PDF_2026-10-26.md) | Implementação, validação e limites da exportação |

Comece pelo manual se deseja usar o programa. Para desenvolver uma integração, configure o acesso no manual, leia o protocolo e escolha o cliente socket ou DLL. Os dois caminhos exigem o aplicativo em execução e usam a mesma autorização.

## Versões e documentação anterior

Esta documentação descreve as fontes atuais, incluindo a integração externa v1. O instalador histórico **0.120**, publicado antes dessa integração, contém os avatares v4 e as correções de voz/anatomia; **não contém a nova API DLL/socket**. Para a integração, compile as fontes atuais conforme o [guia do projeto](Projeto/README.md#compilação). Não basta copiar uma DLL para uma instalação antiga.

| Referência | Finalidade |
| --- | --- |
| [Instalador 0.120](INSTALACAO_0120.md) | Pacote anterior, instalação, hashes e validação daquele pacote |
| [Professor virtual 3D](professor-virtual-3d.md) | Modelos, esqueleto, renderer, áudio, autoria e limites |
| [Comandos da IA para o avatar](avatar-comandos-ia.md) | Tags de gesto, composição e sincronização da apresentação |
| [Assinatura vocal Android](ASSINATURA_VOCAL_ANDROID.md) | Protótipo e contexto histórico do fluxo Android |
| [Continuidade técnica](CONTINUIDADE_ASSISTENTE.md) | Registro histórico para manutenção |

O antigo receptor de texto bruto na porta 18765 não é iniciado pela aplicação atual. Clientes desse protótipo precisam migrar para o protocolo autenticado v1. Código legado preservado não equivale a um serviço ativo.

As versões são independentes: versão do instalador, versão artística do avatar (v4), versão JSON do protocolo (`v:1`) e versão da ABI da DLL (`0x00010000`). Confira sempre qual delas um documento descreve.


## Editor de Apresentações PVA

Editor Lazarus independente, pacote único com roteiro e mídias, geração de gestos por IA e execução no Assistente com pausa/retomada.

Consulte o [manual do editor](editor-apresentacoes.md), o [catálogo de tags](tags-apresentacoes.md), o [formato PVA](formato-pva.md) e o [status de conclusão](plano-conclusao-editor-apresentacoes.md).

A revisão pós-integração, os programas recompilados e os limites dos testes estão no [relatório de 24/10/2026](VALIDACAO_2026-10-24.md).

Consulte o [guia do Editor de Movimentos (prévia)](editor-movimentos.md).

A revisão com poses XYZ, vistas CAD e padrão visual MultiCNC está descrita na [validação do editor 3D](VALIDACAO_EDITOR_3D_2026-10-24.md).


## Integração de branches

Consulte a [integração de 26/10/2026](INTEGRACAO_BRANCHES_2026-10-26.md), que reúne a versão 0.217, as correções de voz e os menus de arquivos/PDF/pesquisa.
