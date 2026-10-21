# Professor Virtual 3D — integração Lazarus

## Estrutura preservada

Base inspecionada: `3aa0cf21d3a58bef79d1c3998ad3d7d1bf5e3dce`.
A tela já possuía chat, entrada, memória, agentes, API Jarvis e trabalhos de voz.
O avatar era um GIF estático. A integração conserva `TAssistantManager`,
`TAIAgentMemoryMap`, `TVoiceInputBridge`, `TReceptionJob`, a configuração e
as implementações existentes de câmera/Kinect. O desenho 2D legado em
`reception_avatar.pas` permanece no repositório.

`TProfessorView` cria `TCastleControl`, `TCastleViewport`, iluminação e
`TCastleScene` dentro do formulário. Não utiliza CEF ou servidor web.
Somente a thread LCL modifica o renderer. O contexto OpenGL é fechado antes
de liberar o container, viewport e cenas. `TProfessorStateMachine` decide as
prioridades. `TProfessorListener` adapta a biblioteca de voz fixada em vendor:
eventos da captura entram numa fila protegida e são entregues à LCL por timer.
A escuta pausa durante STT, IA e TTS, retomando após conclusão/falha.
Os trabalhos de fala e de agentes são acompanhados e liberados ao encerrar.

## Layout e modelos

A interface segue a disposição da referência: cartão branco do avatar à
esquerda, conversa em balões à direita, campo inferior arredondado e ícones
de enviar/configurar abaixo, indicador de microfone sob o avatar e rodapé de
estados. Não há mensagens de IA pré-fabricadas na aplicação; a captura de
teste usa mensagens demonstrativas explicitamente identificadas como tal.

No cartão há seletor, atualizar lista (↻), acenar e caminhar. O mínimo é
740 × 450; as colunas se adaptam ao tamanho da janela.

Incluídos: Professor, Médico, Engenheiro, Programador, Dona de casa,
Empresário, Padre, Criança, Bebê e Robô. A versão 3 substitui a montagem de
primitivas por anatomia contínua e vestuário ajustado, derivados dos recursos
oficiais CC0 do MakeHuman. São aproximadamente 33–54 mil triângulos por modelo,
163 juntas, quatro influências normalizadas por vértice, UVs, texturas de pele,
mechas de cabelo com recorte alfa e materiais com normais/oclusão de tecido.
O professor inclui um colete argyle; o robô tem cerâmica clara e headset ciano.

Cada modelo tem 28 clipes: seis estados básicos e composições de sorriso,
mão direita levantada e aplausos com/sem fala. Boca, pálpebras e sorriso usam
morph targets. Trajetórias são amostradas a 60 Hz com aceleração suave, IK
nas pernas/poses de mãos, oposição de braços e pernas e apoio/avanço dos pés.
O renderer mistura estados em 0,32 s e levantar/baixar a mão em 0,6 s.
Esse valor de amostragem não é uma garantia de FPS no equipamento do usuário.

O gerador é `tools/generate_professor.py`, com numpy/Pillow apenas na autoria.
Fontes artísticas, hashes e licenças estão em `tools/avatar-source/`; não é
necessário instalar MakeHuman para gerar ou executar. Todos os recursos
gráficos incluídos são CC0 (veja `AVATARES/LICENSE.txt`). São adaptações para
tempo real, sem equivalência exata às referências, sem fotorrealismo, captura
de movimento ou simulação física de tecido. Profissão altera a aparência.

A IA dirige gestos com tags na resposta; o worker entrega os comandos à LCL
antes do respectivo trecho falado. As tags são removidas do chat, memória e
TTS. Consulte [vocabulário, exemplo e sincronização](avatar-comandos-ia.md).
Esc cancela a apresentação; sem fala automática, tags usam tempo de leitura
estimado, sem abrir serviços de voz.

## Pasta AVATARES e inclusão de novos personagens

A aplicação descobre `.glb` e `.gltf` na pasta **AVATARES ao lado do executável**.
Quando executada a partir de `src`, também procura `../AVATARES`.
Copie os modelos com seus `.bin` e texturas, preservando caminhos relativos.
Subpastas são aceitas até seis níveis. Clique em ↻ para reler a pasta sem
recompilar nem reiniciar o programa. A seleção é persistida pelo ID em
`AVATAR3D_PROFILE`; arquivos avulsos usam seu caminho relativo como ID.

Para um nome amigável e ID estável, crie uma pasta por modelo:

```text
AVATARES/
  meu-personagem/
    avatar.json
    modelo.glb
    modelo.ini      (opcional)
```

```json
{"id":"meu-personagem","name":"Meu personagem","model":"modelo.glb"}
```

IDs precisam ser únicos. Manifestos inválidos e modelos ausentes produzem
diagnósticos na dica do seletor e não bloqueiam os outros arquivos.
O catálogo valida referências/extensões; o loader real do Castle valida a
malha quando selecionada. Arquivo quebrado tenta o professor incluído e
mostra o diagnóstico. Também permanece a escolha direta por
**Config. → Avatar 3D → Modelo personalizado** (`AVATAR3D_MODEL`).

Modelos devem usar Y para cima, olhar para +Z e ter origem próxima dos pés.
O enquadramento usa a altura da geometria. Outros pivôs/orientações devem ser
ajustados antes da exportação.

**Roda para cima aproxima, para baixo afasta**, somente sobre o renderer.
Há limites de distância. **Duplo clique reenquadra**; trocar de modelo também
restaura a distância. O zoom não modifica o modelo salvo.

| Evento | Clipe |
| --- | --- |
| Pronto | `idle` |
| Voz detectada | `listening` |
| STT, agente ocupado ou preparação de voz | `thinking` |
| Reprodução de voz | `talking` |
| Aceno / abertura | `wave`, retorno após 2,4 s |
| Caminhada | `walk`, retorno após 2,4 s |

Fala/pensamento têm prioridade sobre os botões manuais de gesto. Comandos da
resposta da IA podem compor sorriso e mão levantada com a fala; aplausos
dirigidos pela IA também podem acompanhar a voz. Caminhada é um ciclo no lugar.
Os clipes incluídos restabelecem todas as articulações animadas ao trocar.
Para outros nomes, use um `.ini` com o mesmo nome do modelo:

```ini
[animations]
idle=Idle
listening=Listen
thinking=Think
talking=Talk
wave=Wave
walk=Walk
```

Clipes ausentes são informados e usam idle quando disponível. A prévia da aba
de configuração reproduz os seis estados de verdade, sem afirmar sucesso por
uma simples mensagem. Auto-idle é funcional. Piscar está nos clipes incluídos;
a fala tem animação genérica de boca, sem sincronização por fonemas/visemas.
As opções legadas de piscar, qualidade e lip-sync não implementadas pelo
adaptador ficam desabilitadas, preservando os valores anteriores.

## Dependências e build

- Lazarus e FPC 3.2.2 com unidades **i386-win32**. O executável 32 bits também
  funciona em Windows 64 bits via WOW64.
- Biblioteca externa `marcelomaurin/CHATGPT`, normalmente irmã de Assistente.
  A validação usa `febb8e26b2ccfdac58cff175577088b1c48e2b84`; havia alterações
  locais em componentes de joystick não relacionados, que não foram alteradas
  por esta implementação. Vendor de voz tem precedência conforme seu README.
- Castle fixado em `6a433378a8cc7117f5deccbec2fb70a42fdb98f3`.
- Driver OpenGL e suporte à renderização; MSAA 4 é solicitado pelo controle.
- Kinect físico requer SDK/driver correspondente.

```powershell
.\scripts\setup_castle.ps1
.\scripts\build_professor.ps1 -ChatGPT C:\projetos\maurinsoft\CHATGPT -Release
```

Saída: **build/professor/assistente.exe**, junto de **build/professor/AVATARES**.
Distribua ambos e as dependências de runtime já requeridas pelos componentes
CHATGPT/voz usados na sua instalação. O script não atualiza os executáveis
antigos do repositório nem o checkout original.

Parâmetros: `-Lazarus`, `-Castle`/`CASTLE_ENGINE_PATH`, `-Compiler`, `-Platform`,
`-Rebuild` e `-Release` (remove símbolos do executável). Fontes/includes do CGE
vêm dos seus pacotes oficiais. Unidades e logs ficam em `build`, ignorado pelo Git.
Win64 completo encontrou erro preexistente de `QueryInterface` em
`aiguardrails.pas` da biblioteca externa; não foi validado.

No IDE, disponibilize `packages/lazarus/castle_engine_lcl.lpk` e dependências;
`assistente.lpi` já o requer. Use `castle_engine_lcl`, sem `castle_engine_window`.
`ASSISTENTE_CONFIG_DIR` permite isolar a configuração; sem a variável permanece
o caminho original. Nenhuma credencial é incluída nos testes ou modelos novos.

## Verificação

```powershell
python tests/check_avatar_assets.py
python tests/check_avatar_motion.py
.\scripts\build_professor.ps1 -Target tests\professor_commands_tests.lpr -Run
.\scripts\build_professor.ps1 -Target tests\professor_speech_commands_tests.lpr -Run
.\scripts\build_professor.ps1 -Target tests\professor_state_tests.lpr -Run
.\scripts\build_professor.ps1 -Target tests\professor_catalog_tests.lpr -Run -RunArguments build\catalog-fixtures
.\scripts\build_professor.ps1 -Target tests\professor_model_tests.lpr
Get-ChildItem AVATARES -Filter modelo.gltf -Recurse | ForEach-Object {
  & .\build\professor\professor_model_tests.exe $_.FullName
  if ($LASTEXITCODE -ne 0) { throw $_.FullName }
}
.\scripts\build_professor.ps1 -Target tests\professor_ui_smoke.lpr
.\scripts\build_professor.ps1 -Target tests\professor_directive_smoke.lpr
.\scripts\build_professor.ps1 -Target tests\professor_animation_smoke.lpr
```

Execute `professor_ui_smoke.exe` para o teste gráfico isolado: desativa captura,
fala e serviços de IA, percorre o seletor dinâmico, testa o evento da roda,
limites e duplo clique, captura cada renderer em PNG e fecha a janela.
O relatório em `build/professor/ui-smoke/result.txt` também registra falha de
descarte de recursos, se houver. A prévia de layout combina a captura LCL com
a captura real OpenGL porque GetFormImage não inclui o framebuffer 3D.
As mensagens dessa prévia são dados de demonstração.

`professor_directive_smoke.exe` executa o exemplo anotado do usuário na janela
real, sem voz/rede/hardware, verifica sorriso/aplausos/mão levantada/comando final
e Esc. `professor_animation_smoke.exe caminho/modelo.gltf` captura treze poses
e aproximação; um segundo argumento `walk`, `wave` ou `applause_smile` captura
144 quadros nativos a passos de 1/60 s para exportar vídeo contínuo a 60 FPS.
Durante a captura, a janela avança mais devagar para salvar os quadros; a
velocidade final é a do vídeo exportado. A inspeção de treze poses é estática
e está identificada no título, para não confundir com a reprodução contínua.
Os testes de movimento verificam matrizes de vínculo, pele/roupa deformadas,
lado correto da mão e das palmas nos aplausos, apoio/avanço do pé, velocidades
angulares e continuidade das poses nos ciclos. `professor_performance_smoke`
mede a reprodução real durante dez segundos após aquecimento, sem capturar
imagens. A prévia das configurações percorre estados e comandos em reprodução
contínua; o renderer principal fica pausado enquanto o diálogo está aberto.

## Limites

A câmera reutiliza `TWebcamVision` para RGB, e o Kinect `TAIKinectSensor` para
conexão; dispositivos desabilitados permanecem fechados. Não foram adicionados
reconhecimento facial, espelhamento de esqueleto, olhar ou gestos de Kinect
dirigindo o avatar. Os testes não comprovam captura física simultânea nem
conversa completa com provedores remotos; isso exige hardware e credenciais.

Não há barge-in durante fala: a escuta é pausada para evitar realimentação.
SAPI síncrono pode atrasar o fechamento até o trecho corrente terminar;
preparação de voz remota pode aguardar o timeout do provedor.

Referências oficiais:
[TCastleControl no formulário](https://castle-engine.io/control_on_form),
[viewport e cenas](https://castle-engine.io/viewport_and_scenes).
