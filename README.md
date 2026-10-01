# Assistente

Assistente de IA para responder perguntas da FATEC, desenvolvido em Object Pascal
com Lazarus/LCL e Free Pascal. Texto e voz passam pelo mesmo atendimento e memória.

## Compilar e testar

Mantenha `Assistente` e `CHATGPT` em pastas irmãs. A biblioteca foi validada no commit
`4188adf07d027b8df479eb6bf6986a31278a19cb`; detalhes das cópias locais em
`vendor/chatgpt-voice/README.md`. Não é necessário trocar a linguagem do projeto.

No Windows com Lazarus/FPC 3.2.2:

```powershell
C:\lazarus\lazbuild.exe --pcp=.lazarus --build-all src\assistente.lpi
.\tests\run_checks.ps1
python tests/run_with_mock.py
```

O executável recompilado é `src/assistente.exe` (Windows x64). Feche versões antigas
antes de abri-lo. DLLs usadas em execução precisam ter a mesma arquitetura.
O script `compile_check.bat` também pode ser usado a partir de qualquer pasta.
Os testes usam configurações isoladas e o teste HTTP utiliza apenas loopback.

## Atendimento com documentos

Crie `knowledge` ao lado do executável e coloque documentos institucionais revisados
em UTF-8 (`.txt` ou `.md`, até 1 MiB por arquivo). O atendimento recupera até quatro
trechos por BM25, informa ao modelo suas fontes e orienta reconhecer quando faltar
evidência. Nenhum documento institucional fictício acompanha o projeto.

Uma pergunta gera uma chamada ao modelo. O histórico enviado contém até 12 turnos.
As fontes devem ser revisadas por um responsável; RAG não garante a veracidade de
todo conteúdo gerado. Veja as limitações e a evolução proposta na revisão técnica.

## Configurações e voz

A tela existente carrega e salva provedor, modelo, áudio, banco e visão por `TSetMain`.
O modelo escolhido é preservado. O microfone fica pausado durante reconhecimento,
processamento e reprodução da resposta; volta após o job terminar ou falhar.
Configurações ficam na pasta de dados do usuário. `ASSISTENTE_CONFIG_DIR` permite
selecionar uma pasta alternativa, especialmente para testes. A memória fica na
subpasta `reception`; um histórico antigo ao lado do executável ainda pode ser lido.

## Vídeo e limitações atuais

Configurações → Vídeo permite enumerar e testar Kinect v1 e câmeras VFW locais.
As escolhas são independentes. Com vários dispositivos, uma seleção inválida não
é substituída automaticamente pelo primeiro. Dispositivos apenas DirectShow/Media
Foundation podem não aparecer. Os índices podem mudar após troca de portas/drivers.

A tela principal atual não integra captura contínua de Kinect/câmera nem avatar 3D.
O avatar apresentado é estático. Áudio físico, eco, pausas e dispositivos precisam
ser validados no equipamento final. O backend atual usa o microfone padrão do SO.

## Revisão e segurança

Leia [a revisão técnica](docs/REVISAO_TECNICA.md) e
[as pendências de continuidade](docs/CONTINUIDADE_ASSISTENTE.md).
A chave JARVIS anteriormente embutida deve ser substituída no servidor porque ainda
existe no histórico Git. As configurações novas não incluem essa chave.
