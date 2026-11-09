# Tarefa: QuestionDetector (issue #10, US-02)
Objetivo: detectar o fim da pergunta e emitir "pergunta completa" uma única vez, para disparar a resposta sem tocar em nada.
Aceite (PRD): dado fala com pausa ao fim da pergunta, quando a pausa passa do limiar configurado, então o app emite "pergunta completa" uma única vez.
Leia antes: docs/PRD.md (US-02), docs/API.md (seção 7), Teleprompter/Domain/QuestionDetector.swift (protocolo atual, pode ser refinado), Teleprompter/Domain/Models.swift (Transcript), TeleprompterTests/ (padrão de teste).
Arquivos permitidos: Teleprompter/Domain/QuestionDetector.swift, Teleprompter/Domain/PauseQuestionDetector.swift (novo), TeleprompterTests/QuestionDetectorTests.swift (novo). Não edite docs/ nem project.yml.
Comportamento:
- Entrada: sequência de `Transcript` (parcial/final) e os segundos de silêncio desde a última fala.
- Emite o texto da pergunta quando há texto não vazio e silêncio >= limiar (padrão 1,2 s, configurável no init). Emite uma única vez por pergunta.
- Depois de emitir, zera o estado; um novo parcial começa outra pergunta. Parcial que reescreve o anterior (texto mais longo ou corrigido) substitui, não concatena.
- Sem texto, ou texto só de espaços, nunca emite. Silêncio abaixo do limiar não emite. Chamadas repetidas com silêncio alto depois da emissão não emitem de novo.
- Se o protocolo precisar de estado, troque para `mutating func` ou use uma struct/classe; mantenha Sendable e Swift 6 sem warnings.
Faça: testes primeiro (transcrições parciais sintéticas: emite uma vez, abaixo do limiar, texto vazio, reescrita de parcial, duas perguntas seguidas, limiar customizado), depois o código. Rode xcodegen generate, swiftlint --strict e xcodebuild test (iPhone 17) até verde.
Regras: iOS 17.2+, Swift 6, sem dependência nova, sem texto de fala em log, comentário só quando o porquê não é óbvio.
Proibido: git commit/push/merge, gh, ler .env ou Keychain, editar .github/ e project.yml.
Entregue: resumo de 5 linhas do que mudou e do resultado dos gates.
