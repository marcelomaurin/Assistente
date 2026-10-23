# Formato PVA versão 1

`.pva` é um ZIP sem senha. Todos os nomes são relativos e usam `/`.

```text
manifest.json
script.txt
assets/<recurso.png>
assets/<recurso.pptx>
```

`script.txt` contém o roteiro UTF-8, sem normalizar espaços ou quebras de linha. `manifest.json` é JSON UTF-8:

```json
{
  "format": "pva",
  "version": 1,
  "script": "script.txt",
  "hash": "sha256",
  "files": [
    {"path": "script.txt", "size": 123, "sha256": "<64 caracteres hexadecimais minúsculos>"},
    {"path": "assets/figura.png", "size": 456, "sha256": "<64 caracteres hexadecimais minúsculos>"}
  ]
}
```

Os tamanhos são bytes descomprimidos. A lista inclui todos os arquivos exceto o próprio manifesto. Cada entrada precisa existir exatamente uma vez, com tamanho e SHA-256 correspondentes. SHA-256 verifica integridade; o formato não contém assinatura de autoria.

Limites: 256 entradas, 64 MiB por arquivo, 256 MiB de ZIP ou conteúdo total expandido, 1 MiB de roteiro/manifesto e menos de 4096 eventos no roteiro. O consumidor aceita somente versão 1, compressão ZIP armazenada/deflate, `script.txt`, `manifest.json` e recursos de mídia suportados em `assets/`.

São recusados caminhos absolutos, `..`, componentes vazios, barras invertidas, ADS, nomes de dispositivos Windows, caracteres de controle, NUL, nomes duplicados sem distinguir maiúsculas/minúsculas, diretórios explícitos, links simbólicos e recursos fora do inventário. Os cabeçalhos locais também passam pelas verificações de caminho. A extração usa streams limitados e só grava depois da validação de todo o inventário e do roteiro.

O exportador inclui apenas mídias referenciadas por tags reconhecidas. O editor usa SHA-256 como nome interno do recurso importado, conservando a extensão. Dois usos do mesmo arquivo reutilizam uma entrada. A gravação produz um arquivo temporário e substitui o destino somente ao final.

## Utilitário

```powershell
pva_tool.exe selftest
pva_tool.exe pack roteiro.txt pasta-do-projeto apresentacao.pva
pva_tool.exe verify apresentacao.pva
pva_tool.exe verify apresentacao.pva pasta-nova
```

`pasta-do-projeto` contém `assets/`. O destino de extração precisa ser novo, para não sobrescrever arquivos alheios. Erros retornam código 1. O utilitário aceita caminhos Windows com espaços e Unicode.

A versão 1 não referencia arquivos externos, URLs ou executáveis. Vídeos e PowerPoint conservam seus formatos originais e precisam das dependências de reprodução descritas no [manual](editor-apresentacoes.md).


A versão 1 também permite recursos de som WAV/MP3/WMA em assets/. A opção de início temporal e as escolhas de avatar/voz ficam no roteiro; o inventário aponta somente para os arquivos reais, sem incluir o sufixo |inicio=. Avatar e voz são referências às opções instaladas/configuradas na máquina executora, não arquivos embutidos. Pacotes com essas tags precisam do executor atualizado.
