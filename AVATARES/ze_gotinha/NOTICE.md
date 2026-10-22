# Zé Gotinha — adaptação para o Assistente

Modelo 3D refeito em 22/10/2026 com as seis imagens fornecidas pelo usuário
como referências visuais. As imagens de referência não são distribuídas aqui.

Cabeça em gota, corpo implícito arredondado, mãos, pés, olhos, boca e emblema
foram construídos por geometria procedural. O esqueleto e os movimentos usam
a estrutura do Assistente derivada dos recursos artísticos CC0 do MakeHuman;
consulte `tools/avatar-source/README.md` e `AVATARES/LICENSE.txt`.

O personagem Zé Gotinha e a marca SUS são referências de terceiros. Esta
adaptação não declara esses elementos como CC0 nem presume domínio público.

## Reprodução

Na raiz do projeto, com as dependências de `tools/avatar-requirements.txt`:

```powershell
python tools/game_avatar.py --profile ze_gotinha
python tests/check_ze_gotinha.py
```

O gerador específico é `tools/ze_gotinha_avatar.py`. SciPy é usado somente na
autoria; o aplicativo continua carregando glTF e PNG sem depender de Python.
O rosto usa rotação de mandíbula/olhar e escala animada para piscadas,
compatíveis com o motor Castle atual. Não depende de morph targets.

Mantém os 28 clipes do Assistente e o ID `ze_gotinha`. O corpo é uma superfície
fechada e conectada, sem roupa, tênis, nariz ou orelhas humanas. A cabeça
arredondada termina em uma ponta curva; o emblema SUS acompanha o tronco.

O instalador histórico não é atualizado por esta alteração. Para o executável
de desenvolvimento, a mesma pasta de avatar deve ficar em
`build/professor/AVATARES/ze_gotinha`.
