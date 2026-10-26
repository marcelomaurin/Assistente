# Instalacao 0.216

Execute `bin/setup_assistente_0216.exe`. O Editor de Tags/Apresentacoes e requisito e permanece instalado, incluindo quando nenhuma tarefa opcional e selecionada.

## Novidades

- `[PERGUNTAR]` e o botao Perguntar pausam o roteiro para perguntas a IA baseadas no texto da apresentacao carregada.
- `[MENU]` substitui a midia anterior pela lista de blocos. Selecao por clique, setas e Enter, ou permanencia do cursor por mais de cinco segundos; sair da opcao reinicia o contador.
- Rolagem por roda, teclado e botoes superiores e inferiores; entrada `IR {nome do bloco}` por texto ou transcricao de voz.
- `[CONTINUAR]` e uma tag de controle que retoma o roteiro interrompido, incluindo pausas aninhadas.
- Imagens, filmes, menu e respostas ficam acima da area de digitacao.

Consulte [perguntas durante a apresentacao](perguntas-apresentacao.md). O pacote inclui o roteiro e a apresentacao de exemplo em `examples/perguntas-menu`.

## Ferramentas incluidas

Assistente, Editor de Tags/Apresentacoes, ferramenta PVA, previa do Editor de Movimentos e Criador Avatar com Python isolado e bibliotecas incluidas. Mantem reconhecimento de voz pelo Chrome ou OpenAI, filtro de fala e detector de silencio.

A atualizacao reconhece o catalogo padrao entregue em 0.215. Catalogos editados pelo usuario, configuracoes, historico, avatares pessoais e movimentos personalizados sao preservados.

A IA usa o texto do roteiro; nao faz leitura automatica de textos presentes apenas nas imagens ou slides. A voz utiliza o provedor e as credenciais ja configurados.
