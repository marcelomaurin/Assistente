# Dependências de voz do Assistente

Fontes originais de https://github.com/marcelomaurin/CHATGPT
Commit: `838d24158dab7fa19df0f565c83b000da77d3095` (pacote/AI Voice).

Esta cópia fixa as unidades requeridas pelo Assistente que ainda não estão
na branch main da biblioteca local. Evita alterar o checkout compartilhado
de CHATGPT ou remover escuta contínua, supressão de eco e barge-in.
O compilador usa estas unidades antes da biblioteca externa.
Os demais componentes continuam vindo de ../../CHATGPT.
