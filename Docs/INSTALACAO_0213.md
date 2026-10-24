# Assistente 0.213 — correção da regressão dos movimentos

Esta versão corrige a interrupção de movimentos introduzida na 0.212. A proteção anterior usava volumes excessivos para as mãos e os percursos importados não tinham sido calibrados para esses volumes. Gestos como OK, fechar a mão e cruzar os braços podiam parar antes do fim, principalmente no Zé Gotinha.

- As cápsulas das mãos agora representam a palma, sem alongar a espessura da mão até a ponta dos dedos.
- A altura de referência da calibração é registrada no JSON por avatar. O Zé Gotinha tinha altura de enquadramento de cerca de 1,557, diferente da referência de 1,371 usada para gerar as trajetórias; usar o enquadramento aumentava indevidamente volumes e deslocamentos.
- Os percursos dos braços são calibrados no JSON por avatar para respeitar os volumes de colisão.
- O cálculo do deslocamento usa a distância real até cada articulação e os deslocamentos dos volumes, evitando a estimativa excessiva baseada em duas alturas completas do personagem.
- A transição de sentar para levantar afasta os braços antes de estender as pernas e subir o corpo, evitando o contato entre mãos e coxas. A sequência é definida no JSON com captura da pose atual no primeiro ponto.
- O aviso de bloqueio anterior é limpo ao iniciar outro movimento válido.
- A atualização substitui os dois arquivos padrão intactos da 0.212: `AVATARES/movimentos.json` e `AVATARES/colisoes.json`. Arquivos personalizados continuam preservados.

Os novos testes exigem conclusão efetiva de cada movimento, além da ausência de sobreposição. A janela de teste nativa verifica a reprodução pelo ciclo real de atualização da interface; uma janela fora da tela não serve para esse teste, pois o sistema pode suspender a atualização gráfica.

Os arquivos continuam editáveis sem recompilação e a proteção continua ativa. Cápsulas são aproximações do corpo: alterações em malhas, roupas ou trajetórias exigem calibração própria.

O instalador é `bin/setup_assistente_0213.exe` e reúne o Assistente e o Editor.

```powershell
python scripts/build_presentations.py --release --compiler C:/lazarus/fpc/3.2.2/bin/i386-win32/fpc.exe --out build/presentations-0213
./scripts/build_installer.ps1 -Version 0.213 -BuildCode 0213
python tests/check_installer.py --build-code 0213 --version 0.213 --no-ui
```
