# Integração das branches — 26/10/2026

## Escopo

Integração de `release-0217` (`fb3a31f1b4910fc05767c4f4d2730760061c75f9`) e `melhorias/estabilidade-voz-e-atendimento` (`f4e35441691a33eefb6c54bff8374863c768063a`) à main com menus, pesquisa e PDF (`7f1b1aaf7a67f3c15b6d82199e7b7dad0e38833b`). O commit final mantém as duas branches como ancestrais.

## Resolução dos conflitos

- Preservados o avatar 3D, o formulário atual, os menus suspensos e a exportação PDF.
- Incorporados exportação/importação de configurações, documentos RAG, perguntas e menus de blocos durante apresentações, filtros de voz, reconhecimento Chrome e os novos avatares da 0.217.
- O atendimento comum usa uma chamada fundamentada ao modelo por turno, recuperando documentos locais por BM25. A seleção de apresentações permanece uma etapa separada quando há material candidato no catálogo.
- Retidos cancelamento e espera pelo worker no encerramento, com proteção contra callbacks após destruição. Etapas de resposta falhas recebem estado de erro; a conversa não dispara leitura de arquivos sem caminho nem tarefas geradas automaticamente pelo modelo.
- A ponte de transcrição informa o término mesmo em falha; a interface atualiza sua disponibilidade e retoma a escuta conforme a configuração. A captura PCM completa foi preservada, com filtro de voz e respeito à interrupção pelo callback. O adaptador antigo de avatar estático foi substituído pelo `professor_listener` já usado pela interface 3D.
- A reprodução continua usando o player com estado real e pausa/retomada. Foram incorporados o provedor, a voz remota e a velocidade da configuração.
- A gravação/refatoração de configurações da 0.217 foi mantida, com os campos de voz que faltavam no `WriteLines`, leitura de decimais conforme a localidade e proteção dos campos de credenciais. A identificação de chaves continua restrita ao início da linha.
- A revisão antiga foi arquivada em `Docs/Historico`; o README e o formulário antigos não substituem a documentação e a interface atuais. O executável antigo da branch de voz também não substitui o binário de referência atual.

## Validação

O workflow Windows da branch de integração compila o aplicativo e os testes de menus/PDF, configuração, fluxo, RAG, filtro PCM, ponte Chrome, seleção de dispositivos e atendimento. Os testes de IA usam servidor HTTP em loopback; não usam credenciais reais. A validação de documentos inclui fechamento durante uma pausa para perguntas e exportação a partir do pacote carregado.

Validação aprovada no Windows x64: [GitHub Actions 40342378231](https://github.com/marcelomaurin/Assistente/actions/runs/40342378231), no commit `112a491e974aef371428ed340de7130137639252`. Compilação completa do aplicativo e todos os executáveis de teste aprovada. Passaram menus/documentos/PDF, configurações e proteção DPAPI, PCM e interrupção pelo callback, ponte Chrome, fluxo de apresentações, dispositivos, atendimento, falha do provedor, cancelamento imediato, encerramento do worker, uma chamada fundamentada por turno e os seis cenários de seleção RAG. Microfone físico, câmera, Kinect, Office e serviços pagos não são homologados por essa suíte. Os instaladores históricos não são recriados pela integração; o workflow fornece a compilação do aplicativo e seus logs.
