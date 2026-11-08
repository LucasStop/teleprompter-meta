# ADR 0003 — STT on-device da Apple, com nuvem como alternativa

- Status: proposta (decidir no gate G1, protótipos P1 e P2)
- Data: 2026-11-08

## Contexto
A latência domina a experiência, e o áudio dos óculos chega pelo HFP a 8 kHz mono.

Tudo é em português (confirmado em 2026-11-08): o modelo de idioma é só pt-BR e o peso de termos técnicos em inglês é baixo.

## Decisão
`SpeechAnalyzer` com `SpeechTranscriber` (iOS 26), com resultados parciais. STT de streaming em nuvem fica como alternativa se o P2 falhar. Como o app é pessoal, o alvo mínimo pode ser iOS 26.

## Alternativas consideradas
- `SFSpeechRecognizer` com `contextualStrings`.
- STT em nuvem com streaming.
A escolha sai do P1 e do P2.

## Consequências
- Positivas: sem custo por minuto; offline depois de baixar o modelo de idioma.
- Negativas e riscos: cada buffer precisa ser convertido para o formato aceito pelo analisador (formato diferente não gera transcrição nem erro). Sem vocabulário customizado como o `contextualStrings`, o que pesa com termos técnicos do projeto.
- Impacto em testes e design: WER medido com as 30 perguntas gravadas; ajusta o alvo mínimo de iOS no `project.yml`.
