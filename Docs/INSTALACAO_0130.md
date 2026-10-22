# Assistente 0.130 — instalador Windows

Arquivo: `bin/setup_assistente_0130.exe`.

Inclui o aplicativo Lazarus Win32 Release atual e 11 avatares. O Zé Gotinha
foi refeito com cabeça em gota, corpo arredondado, emblema SUS e animações de
boca, olhos, piscadas e dedos. Seus 28 clipes são compatíveis com o motor
nativo; os demais avatares mantêm os modelos v4.

O destino padrão é `%LOCALAPPDATA%\Programs\Assistente`, por usuário e sem
elevação. O instalador inclui os modelos 3D, DLLs OpenSSL, guias e licenças.
Não inclui credenciais, histórico, configuração pessoal nem executáveis de
teste. Não requer Python para executar o aplicativo.

As configurações e o histórico existentes são preservados na reinstalação
e na desinstalação. A execução automática ao concluir é opcional; a
instalação silenciosa não inicia o aplicativo.

## Reprodução e validação

```powershell
.\scripts\build_professor.ps1 -Release
.\scripts\build_installer.ps1
python tests/check_installer.py
```

O manifesto `bin/setup_assistente_0130.manifest.json` contém os hashes SHA-256
do instalador e de cada arquivo empacotado. O relatório
`bin/setup_assistente_0130.validacao.json` registra os testes do próprio setup:
extração e hashes, modelos atuais, bibliotecas SSL, abertura e encerramento,
reinstalação e desinstalação em diretório isolado.

O teste não altera o registro da instalação habitual e usa uma configuração
isolada com o Zé Gotinha selecionado, sem câmera, escuta ou fala automática.
Não valida provedores externos nem hardware físico.
