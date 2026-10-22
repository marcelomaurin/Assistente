# Assistente 0.120 — instalador Windows

Arquivo: `bin/setup_assistente_0120.exe`.

Inclui o professor Lazarus Win32 Release, os dez avatares com corpo completo,
correção do ombro nos gestos, ajuste das camadas de roupa e término real do
áudio remoto. O pacote atualizado contém modelos v4 com mandíbula, lábios,
pálpebras, olhos e dedos articulados por esqueleto e córnea com transparência. Funciona também em Windows de 64 bits via WOW64, com OpenGL.

O destino padrão é `%LOCALAPPDATA%\Programs\Assistente`, por usuário e sem
elevação. Isso mantém o diretório gravável para o histórico e para adicionar
modelos. Uma instalação antiga em Program Files permanece preservada; abra
a versão instalada por este pacote. O assistente é iniciado somente se a
opção final estiver selecionada; instalações silenciosas não o iniciam.

São incluídos AVATARES, DLLs OpenSSL Win32 já presentes no projeto, guias,
licenças e identificação/hash do executável. Não são incluídos configurações,
credenciais, histórico, caches nem executáveis de testes. Hardware Kinect,
drivers, API de IA/voz e serviços externos continuam dependendo da instalação
e configuração do usuário. Não instala Python nem APK Android.

As configurações existentes do usuário não são substituídas. A desinstalação
remove os arquivos empacotados; não há regra para apagar configurações ou
histórico criados pelo usuário.

O nome e a versão 0.120 foram mantidos na revisão das articulações. Quem já
baixou a primeira publicação deve baixar novamente o setup e conferir seu
SHA-256 no manifesto atual. O histórico Git preserva o pacote anterior.

## Reproduzir o pacote

Instale Inno Setup 7 e prepare Castle/CHATGPT conforme o guia do professor.
Depois de compilar e verificar a versão Release atual:

```powershell
.\scripts\build_professor.ps1 -Release
.\scripts\build_installer.ps1
python tests/check_installer.py
```

Os scripts aceitam `-Castle` para reutilizar o mesmo checkout do Castle usado
no build. `build_installer.ps1` também aceita `-Compiler`, `-Executable` e
`-ChatGPT`. Gera o setup e o manifesto SHA-256 em `bin`.

O teste usa o próprio setup com `/VERIFYINSTALL=1 /VERYSILENT`, em diretório
novo de `build`, sem atalhos nem registro da instalação de teste. Confere
todos os hashes extraídos, inicia e fecha o executável com configuração
isolada e captura/serviços desativados, testa reinstalação preservando arquivos
do usuário e executa a desinstalação. O resultado fica ao lado do manifesto.
Esses testes não validam conversa com provedor real ou microfone físico.
