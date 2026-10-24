# Assistente 0.212

O instalador `bin/setup_assistente_0212.exe` reúne o Assistente e o Editor atualizados.

- Corrige a falha ao perguntar quando a seleção de apresentações retorna JSON dentro de um bloco Markdown. Antes, a leitura parava nas crases com `Invalid character at line 2, pos 0`.
- Os movimentos padrão agora usam membros, posições, trajetórias e tempos no JSON compartilhado.
- A reprodução verifica os volumes de colisão durante o percurso e para antes do contato previsto.
- O editor oferece **Testar movimento**, velocidade reduzida, pausa e aviso das partes envolvidas no bloqueio.

Consulte `movimentos-json.md` para criar trajetórias e calibrar os volumes. A proteção por cápsulas aproxima o corpo; não substitui a calibração das roupas e superfícies de cada modelo.

Catálogos originais intactos recebem a atualização. Movimentos e perfis personalizados são preservados.

```powershell
python scripts/build_presentations.py --release --compiler C:/lazarus/fpc/3.2.2/bin/i386-win32/fpc.exe --out build/presentations-0212
./scripts/build_installer.ps1 -Version 0.212 -BuildCode 0212
python tests/check_installer.py --build-code 0212 --version 0.212 --no-ui
```
