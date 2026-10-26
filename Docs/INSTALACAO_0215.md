# Assistente 0.215 — voz, editor de movimentos e Criador Avatar

O [instalador 0.215](../bin/setup_assistente_0215.exe) inclui tudo da 0.214 e mais:

- **Criador Avatar** (`criador_avatar.exe`): cria avatares com os controles de corpo e rosto do MakeHuman, escolhe pele, olhos, cabelo, roupa e acessórios, mostra a prévia 3D e grava o avatar em `AVATARES` com os movimentos calibrados. Veja o [guia](criador-avatar.md).
- **Importação**: perfis do MakeHuman (`.mhm`) e personagens do Avaturn e do Tripo3D (`.glb`), além de geração no Tripo3D a partir de uma foto (com a chave de API do usuário).
- **Sete novos avatares**: Professora (óculos, blusa e jeans), Professora loira, Professora de cachos, Professora de cabelo preto (terninho e crachá), Professor de terno, Professor de barba e Professor de óculos (terno e gravata). Total: 18 avatares.
- **Corpo pela regra completa do MakeHuman** nos novos avatares (gênero, idade, peso e etnia combinados), com ajustes de rosto por perfil, cabelo longo em camadas (liso e cacheado), sapato fechado, gola aberta sem gravata, crachá com cordão, argolas, óculos de armação escura ou de metal e barba pintada na pele.
- **Reconhecimento de voz**: Chrome sem chave de API, com autorização do microfone no navegador, ou OpenAI Whisper com token específico de transcrição e reutilização do token IA/ChatGPT. Veja o [guia de voz](reconhecimento-voz.md).
- **Filtro de fala e silêncio**: faixa de 100 a 7000 Hz, análise de ruído de fundo e tempo mínimo de fala; pausa da escuta durante a resposta do Assistente.
- **Editor de movimentos**: lista de membros ajustável à altura da janela e painel de controles com rolagem, mantendo edição XYZ e as vistas de câmera.
- **Editor de tags obrigatório**: instalado em todas as instalações, inclusive sem selecionar atalhos opcionais.
- **Python embutido e isolado** (`runtime/python`: CPython 3.12.7 x64, numpy 2.0.2, scipy 1.14.1 e Pillow 11.3.0), usado pelo gerador do Criador Avatar sem depender do Python instalado no computador.

As imagens de referência dos sete avatares ficam em `imgs/` no repositório. Os avatares são personagens de jogo gerados por script a partir das referências; não reproduzem o rosto das fotos. Para um resultado fotorrealista, gere o modelo no Avaturn ou no Tripo3D e importe pelo Criador Avatar.

## Instalar

Execute o instalador normalmente; não é preciso desinstalar a 0.214. O menu Iniciar recebe **Criador Avatar do Assistente** e o guia correspondente; o atalho na área de trabalho é opcional.

O catálogo padrão de movimentos da 0.214 (sem alterações) é atualizado com as receitas dos sete novos avatares. Catálogos personalizados permanecem intactos: nesse caso, os novos avatares usam a receita geral até que o catálogo seja atualizado (por exemplo, gerando o avatar de novo no Criador Avatar). Avatares criados pelo usuário em `AVATARES` não são removidos na reinstalação nem na desinstalação.

## Build

Windows:

```powershell
python scripts/build_presentations.py --release --out build/presentations-0215
python scripts/build_installer.py --version 0.215 --build-code 0215 --python-runtime <pasta do Python 3.12 isolado com numpy/scipy/Pillow>
```

## Validação

Esta geração é compilada no Windows com Free Pascal 3.2.2, Lazarus e Inno Setup. Os programas são recompilados em modo release. As verificações de voz, áudio, catálogo, layout e rolagem passaram antes do empacotamento.

A validação do instalador usa uma pasta isolada em `build`, confere os arquivos por SHA-256, executa a prévia 3D instalada, verifica a atualização real a partir da 0.214 e a preservação de configuração, histórico e movimentos personalizados. O resultado final fica no [relatório do instalador](../bin/setup_assistente_0215.validacao.json).

Fala real no Chrome/OpenAI, microfone, câmera, Kinect e contas reais do Avaturn/Tripo3D não são exercitados pelos testes automáticos. O Chrome requer instalação separada e autorização do microfone; sua API de voz não requer chave. A opção OpenAI usa a credencial configurada e está sujeita à cobrança do serviço.
