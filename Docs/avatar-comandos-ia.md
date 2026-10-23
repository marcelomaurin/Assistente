# Gestos dirigidos pela IA

A resposta final do provedor configurado pode conter comandos entre colchetes.
O Assistente executa os comandos na ordem e remove somente as tags reconhecidas
do texto apresentado no chat, da memória da conversa e da fala enviada ao TTS.

```text
[sorriso] Oi! [aplausos] Muito obrigado por estar aqui.
[levantar mao direita] Se tiver uma dúvida, este é o gesto de levantar a mão direita.
[abaixar mao direita] Pode fazer sua pergunta.
```

O comando se aplica imediatamente antes do trecho seguinte. Uma tag no final,
como baixar a mão, também é executada. A mão direita é a do personagem: para
quem olha de frente, aparece do lado esquerdo da imagem.

| Comando | Efeito |
| --- | --- |
| `[sorriso]` | Mantém um sorriso discreto, inclusive enquanto fala. |
| `[neutro]` | Limpa sorriso, mão levantada e gesto transitório. |
| `[aplausos]` | Bate palmas durante até 2,4 s. Pode acompanhar a fala. |
| `[aceno]` | Acena por até 2,4 s. |
| `[caminhar]` | Demonstra caminhada no lugar por até 2,4 s. |
| `[levantar mao direita]` | Levanta a mão direita e mantém a pose. |
| `[abaixar mao direita]` | Baixa a mão, preservando o sorriso. |

Maiúsculas, acentos e espaços extras são aceitos. Também são aceitos
`[Aplausos]`, `[levantar mão direita]`, `[abaixe mao direita]`,
`[abaixe a mão direita]`, `[sorrir]`, `[aplaudir]`, `[acenar]` e `[caminhada]`.
Não há execução de comandos de sistema, arquivos ou ações de casa por essas
tags: o vocabulário é uma lista fechada de animações do avatar.

As instruções e os efeitos dos comandos são anexados à solicitação de síntese
da resposta final em `TAssistantManager`, usando `AvatarInstructionText`.
Isso se aplica ao provedor selecionado em `TCHATGPT`. As solicitações internas
de planejamento/JSON não recebem essas instruções, preservando seu formato.
O modelo pode optar por não usar gestos; o aplicativo não inventa uma tag
ausente na resposta. O comando não garante especialização profissional da IA.

## Ordem e fala

`professor_commands.pas` analisa a resposta, separando texto e comandos.
`TReceptionJob` fala cada trecho inteiro entre comandos, preservando melhor
a prosódia que o recorte antigo a cada oito palavras. O worker entrega a tag
por uma caixa de mensagens; o timer LCL aplica a animação e confirma a entrega
antes de começar o trecho falado. Nenhum callback de voz altera OpenGL.

No TTS remoto, o áudio do trecho é preparado antes de disparar as tags que o
precedem. Isso evita que o gesto comece durante a espera pelo provedor.
O job desativa `AutoPlay` e o cache do sintetizador para controlar o início
e o arquivo temporário do áudio. O player consulta o dispositivo MCI no Windows
até o término real; tamanho de arquivo e metadados WAV não determinam a espera.
A escuta permanece pausada até o job concluir ou cancelar a reprodução.
A geração de cada trecho remoto ainda pode introduzir pausas entre trechos;
não há alinhamento por palavra ou por fonema, nem antecipação de áudio.
No SAPI, o comando é aplicado imediatamente antes da chamada síncrona.

Com **fala automática desativada**, scripts com tags continuam apresentando
gestos, usando tempo estimado de leitura (340 ms por palavra, com limites).
Nesse modo não há reprodução, captura ou chamada a provedor de voz. Respostas
sem tags continuam sendo exibidas imediatamente, como antes.

Sorriso e mão levantada permanecem até um comando correspondente, nova pergunta,
troca de modelo, cancelamento ou erro. Um novo gesto transitório substitui o
anterior. Aplausos e aceno terminam após 2,4 s; ao terminar, voltam à pose
persistente atual. **Esc** cancela a apresentação e limpa os gestos. A chamada
SAPI síncrona ou uma requisição TTS já em andamento ainda pode levar tempo até
retornar; o encerramento aguarda o worker para liberar os recursos.

Tags desconhecidas, colchetes incompletos, links Markdown, tags escapadas e
trechos de código são tratados como texto literal. São aceitos no máximo 64
eventos de animação por resposta; tags reconhecidas excedentes são removidas
da voz, mas não são executadas. Não há um interpretador de instruções livre.

## Movimento e modelos personalizados

Os modelos incluídos têm seis estados básicos, 22 variantes/composições e
37 movimentos do catálogo, totalizando 65 clipes: sorriso, mão levantada e combinações, além de aplausos com/sem fala.
O parser controla a intenção; `TProfessorView` escolhe a composição adequada.
O corpo usa skinning com até quatro pesos normalizados por vértice, e o rosto
usa os morph targets `jawOpen`, `blink` e `smile`.

As trajetórias são amostradas a 60 Hz: aceleração/desaceleração suave nos gestos,
respiração, movimento discreto de cabeça e quadril, oposição dos braços e
pernas na caminhada, IK de dois segmentos para pernas e poses de mãos.
Aceno e mão levantada distribuem a elevação entre clavícula, ombro e braço,
evitando manter o ombro fixo enquanto o segmento abaixo do deltoide gira.
Os dez modelos incluem corpo completo sob roupas separadas; o ajuste do tecido
à pele mantém os braços visíveis sem atravessar a roupa nas poses inspecionadas.
O renderer mistura estados em 0,32 s; levantar/baixar a mão usa 0,6 s.
Isso é animação criada para tempo real, sem captura de movimento e sem
simulação física de tecido ou locomoção pelo ambiente.

Nos aplausos, as palmas são orientadas uma para a outra com correção de
lateralidade, e a rotação é distribuída entre antebraço e punho. Os testes
verificam o sentido das duas palmas, e não apenas a posição dos pulsos.
A janela principal pausa seu renderer durante as configurações/prévia,
evitando duas superfícies OpenGL animadas em paralelo atrás do diálogo.
Na medição de 22/10/2026 em reprodução contínua, sem captura concorrente,
o Engenheiro com corpo completo teve média de 59,91 FPS, percentil 95 de
17,91 ms por quadro e máximo de 50,52 ms, em 602 quadros medidos. Esses números
descrevem a máquina e a execução do teste, não uma garantia geral.

Arquivos externos continuam podendo ter somente os seis clipes básicos.
Composições seguem nomes como `talking_smile_right_hand_up`, `idle_smile`,
`applause` e `applause_talking_smile`. Se o modelo não oferecer um comando,
o renderer avisa e usa a melhor animação disponível, mantendo o chat.
O sistema não cria automaticamente rig, pesos ou clipes para arquivos importados.

## Limites e validação

Essas tags movimentam o personagem; não reconhecem mãos levantadas de pessoas
nem ligam a câmera ou microfone. A retomada de escuta mantém as configurações
existentes do Assistente. As instruções da IA explicam essa distinção.

Os testes de parser, sequência entre trechos, cancelamento e apresentação LCL
isolada não usam serviços externos. Testes com TTS/IA remotos e hardware físico
exigem a configuração da instalação. Veja também `professor-virtual-3d.md`.


## Novos movimentos

As direções são sempre as do personagem. Os modelos incluídos agora contêm
animações reais para as tags abaixo, com dedos articulados e trajetórias suaves.

| Tag | Movimento |
| --- | --- |
| `[gesticular ok]` ou `[ok]` | Sinal de OK com a mão direita. |
| `[joia]` ou `[positivo]` | Polegar direito para cima. |
| `[concordar]` ou `[cabeca sim]` | Balança a cabeça dizendo SIM. |
| `[negar]` ou `[cabeca nao]` | Balança a cabeça dizendo NÃO. |
| `[coracao com as maos]` | Une as mãos diante do peito em coração. |
| `[levantar mao esquerda]` | Mantém a mão esquerda levantada. |
| `[abaixar mao esquerda]` | Retorna à postura habitual. |
| `[olhar para tras direita]` | Gira a cintura, o tronco e a cabeça pela direita. |
| `[olhar para tras esquerda]` | Gira pela esquerda. |
| `[dar tchau]` ou `[aceno]` | Acena com a mão direita. |
| `[nao com o dedo]` | Balança o indicador direito com os outros dedos recolhidos. |
| `[levantar pe direito]` | Flexiona a perna e mantém o pé direito erguido. |
| `[fechar mao esquerda]` / `[abrir mao esquerda]` | Demonstra fechar/abrir a mão esquerda. |
| `[fechar mao direita]` / `[abrir mao direita]` | Demonstra fechar/abrir a mão direita. |
| `[bocejar]` (também `[bocechar]`) | Abre a boca e semicerra os olhos por 4 s. |
| `[fechar olhos]` / `[abrir olhos]` | Mantém as pálpebras fechadas/abertas. |

Tags aceitam acentos, maiúsculas e sublinhados. Gestos transitórios duram 2,4 s,
exceto o bocejo (4 s). Olhos, mãos, pé, mão esquerda erguida e olhar para trás
são poses persistentes; uma nova pose persistente substitui a anterior.
`[neutro]` limpa todas as poses. A animação de bocejo controla a mandíbula
durante seu intervalo, inclusive durante a fala. Modelos externos precisam
conter os clipes correspondentes para executar esses movimentos.

Para atualizar somente as animações dos modelos existentes:
`python tools/game_avatar.py --update-gestures`.

## Catálogo externo compartilhado

As definições de movimentos agora ficam em `AVATARES/movimentos.json`.
O Assistente, a biblioteca do editor, o parser e as instruções da IA usam
o mesmo catálogo. Consulte [Configurar movimentos por JSON](movimentos-json.md)
para cadastrar clipes ou poses por articulações sem recompilar.

As formas `[cruzar os braços]` e `[cruzar bracos]` executam a mesma pose.
Todos os clipes citados pelo catálogo são validados nos onze modelos distribuídos.
