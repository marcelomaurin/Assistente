# Assistente 0.200 — instalador Windows com Editor de Apresentações

Arquivo: `bin/setup_assistente_0200.exe`.

## Conteúdo

- Assistente Win32 atualizado com execução de apresentações e comandos de documentos.
- Editor de Apresentações (`presentation_editor.exe`), instalado ao lado do Assistente para localizar automaticamente seu executável na prévia.
- Ferramenta `pva_tool.exe` para validar e empacotar apresentações.
- Os 11 avatares, bibliotecas OpenSSL, exemplos de roteiro, documentação e licenças.
- Blocos com retorno, GOTO, FIM, seleção de avatar e voz, imagens, vídeos, sons, slides e publicação PVA/RES na biblioteca RAG.

Os eventos de voz, rosto, mão levantada e reconhecimento de pessoa têm vínculos preparados e validados; ainda não disparam ações. Consulte o [guia de comandos](guia-comandos-assistente.md).

## Instalar e abrir

Execute o setup. A pasta padrão é `%LOCALAPPDATA%\Programs\Assistente`, por usuário e sem elevação. O menu Iniciar recebe atalhos para o Assistente, o Editor de Apresentações e o guia de comandos. Os atalhos na área de trabalho são opcionais e independentes.

Abra o editor pelo atalho, escreva ou abra um PVA, valide e use **Prévia no Assistente**. Avatar e voz usam o catálogo e o provedor configurados no Assistente. Ao salvar, o pacote e seu texto `.res` ficam disponíveis na biblioteca RAG.

O pacote não inclui credenciais, histórico, configuração pessoal nem executáveis de teste. Reinstalação e desinstalação preservam arquivos pessoais existentes. A abertura do Assistente ao concluir é opcional; instalação silenciosa não abre os aplicativos.

Não é necessário Python para executar os programas instalados. PPTX requer PowerPoint instalado e disponível na sessão. Vídeo e áudio dependem dos codecs do Windows; serviços de IA e voz remotos exigem a configuração do usuário.

## Compilar e verificar

```powershell
python scripts/build_presentations.py --release
.\scripts\build_installer.ps1
python tests/check_installer.py
```

O build requer as dependências descritas no [manual do editor](editor-apresentacoes.md). O script do instalador usa por padrão os três executáveis de `build/presentations`; é possível indicar outros arquivos com `-Executable`, `-Editor` e `-Tool`.

As licenças Castle são lidas de `-Castle/doc/licenses` ou da pasta de fontes padrão. `-CastleLicenses` permite indicar uma cópia verificada dessas mesmas licenças, por exemplo de um pacote anterior, quando se reutilizam unidades Castle já compiladas. Isso não substitui as dependências necessárias para compilar o renderer.

O manifesto `bin/setup_assistente_0200.manifest.json` contém o SHA-256 do setup e de cada arquivo do pacote. O `package-info.json` instalado identifica o commit de origem e os hashes dos três executáveis. O relatório `bin/setup_assistente_0200.validacao.json` registra a validação do setup real em pasta isolada:

- Instalação, arquivos e hashes, 11 modelos atuais e ausência de dados pessoais.
- Carregamento das DLLs SSL sem acessar a rede.
- Abertura e encerramento do Assistente e do editor, verificando que o editor seleciona o Assistente instalado ao seu lado.
- Autoteste da ferramenta PVA e empacotamento/validação do exemplo de blocos e eventos.
- Reinstalação e desinstalação preservando arquivos pessoais de teste.

O modo de verificação não cria atalhos nem altera o registro da instalação habitual. Usa configuração isolada, sem câmera, escuta ou fala automática. Não valida hardware físico nem provedores externos.
