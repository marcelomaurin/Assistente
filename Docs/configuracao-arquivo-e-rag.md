# Arquivo de configuração e documentos do RAG

Dois recursos da tela **Configurações** do Assistente.

## Arquivo de configuração

Serve para configurar outra instalação de uma vez: provedor e modelo da IA, voz, reconhecimento de fala, avatar, visão, banco de dados, integração externa e a opção de usar os documentos do RAG.

### Gerar o arquivo

1. Abra **Configurações** e ajuste o que quiser.
2. Clique em **Exportar...** (canto inferior esquerdo).
3. Responda se deseja incluir as credenciais (chave da IA, chave do JARVIS, senhas do banco, token de transcrição e token da integração):
   - **Sim**: o arquivo configura tudo sozinho, mas guarda essas credenciais em texto. Trate o arquivo como uma senha.
   - **Não**: as credenciais ficam de fora. Na outra instalação, elas são informadas em Configurações.
4. Escolha onde salvar. O nome sugerido é `assistente.assistente-config.json`.

O arquivo leva o que está na tela no momento, mesmo antes de **Salvar**.

### Aplicar o arquivo

- Em **Configurações**, clique em **Importar...**, escolha o arquivo e confirme. A configuração é salva e aplicada na hora.
- Ou inicie o Assistente com o arquivo:

  ```
  assistente.exe --importar-config="C:\caminho\assistente.assistente-config.json"
  ```

  Também funciona passando apenas o arquivo `*.assistente-config.json` como argumento (por exemplo, arrastando-o sobre o atalho do Assistente). O resultado aparece na conversa ao abrir.

Itens que não estão no arquivo mantêm o valor atual; por isso um arquivo sem credenciais não apaga as chaves já configuradas. Credenciais importadas são gravadas protegidas pelo Windows (DPAPI) quando o Assistente já as protege.

Não são exportados nem importados os itens próprios de cada computador: posição e tamanho da janela, índices de microfone e Kinect e caminhos de scripts. O nome da câmera e do microfone é levado; confira em Configurações se o equipamento da outra máquina tiver outro nome.

### Formato

JSON em UTF-8:

```json
{
  "format": "assistente-config",
  "version": 1,
  "exported_at": "2026-10-24T18:30:00",
  "contains_secrets": false,
  "settings": {
    "CHATGPTPROVIDER": "1",
    "CHATGPTMODEL": "gpt-4o-mini",
    "SYNTHVOICE": "nova",
    "RECOGLANGUAGE": "pt-BR",
    "AVATAR3D_PROFILE": "businesswoman",
    "RAG_IN_ANSWERS": "1"
  }
}
```

As chaves de `settings` são as mesmas do `Setmain.cfg`. Um arquivo pode ser escrito à mão com só algumas chaves. Arquivos de outro formato ou versão, chaves inválidas e valores com quebra de linha são recusados sem alterar nada.

## Documentos do RAG

A aba **Configurações > Documentos (RAG)** mostra a biblioteca que a IA consulta.

| Botão | Ação |
| --- | --- |
| Adicionar... | Copia um ou mais arquivos para a biblioteca. Pede confirmação antes de substituir um documento com o mesmo nome. |
| Remover | Apaga a cópia da biblioteca. O arquivo original não é alterado. |
| Abrir pasta | Abre a pasta da biblioteca (`%LOCALAPPDATA%\Assistente\RAG`). |
| Atualizar | Relê a pasta, por exemplo depois de copiar arquivos por fora. |

Adicionar e remover valem na hora, sem precisar clicar em Salvar.

Formatos aceitos:

- **Apresentações `.pva`**: a IA pode escolher uma delas para apresentar, como já fazia, e usa o texto do roteiro como referência.
- **Documentos de consulta** `.txt`, `.md`, `.csv`, `.json` e `.rag`: texto UTF-8 de até 1 MB. Servem apenas de referência e nunca são apresentados nem executados. Para PDF ou Word, salve antes como texto.

A coluna **Tipo** mostra *Apresentação*, *Consulta* ou *Com erro*. Um arquivo com erro (por exemplo, texto que não é UTF-8) aparece com o motivo embaixo da lista e não é usado.

### Como a IA usa os documentos

- **Nas respostas comuns** (opção *Usar estes documentos como referência nas respostas da IA*, ligada por padrão): a cada pergunta, até dois documentos relacionados às palavras da pergunta são enviados junto, com o nome do documento. Saudações e perguntas sem relação não enviam nada.
- **Nas perguntas durante uma apresentação** (botão Perguntar ou `[PERGUNTAR]`): o roteiro carregado continua sendo a fonte principal, e até três documentos da biblioteca entram como complemento.
- O comando `carregar arquivo <nome>` também encontra os documentos de consulta adicionados.

O texto dos documentos é tratado como dado: a IA recebe a instrução de não seguir comandos escritos neles.
