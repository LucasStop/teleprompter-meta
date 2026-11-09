# Tarefa: Retriever local com RAG fechado (issue #11, US-03 e US-13)
Objetivo: buscar a resposta nas notas de Q&A, README, documentos e código do material importado, e devolver vazio quando nada passa do limiar.
Aceite (PRD): US-03 dado uma pergunta que casa com uma nota de Q&A, a nota é devolvida sem chamar o LLM. US-13 dado uma pergunta sem trecho acima do limiar de similaridade, o resultado é vazio (o pipeline responde "Não encontrei isso no seu material") e toda resposta carrega as fontes.
Leia antes: docs/PRD.md (US-03, US-11, US-13), docs/adr/0004-*.md, 0006-*.md, 0009-*.md, docs/DATA.md, docs/API.md, Teleprompter/Retrieval/Retriever.swift, Teleprompter/Domain/Models.swift (Chunk, Retrieval, SourceRef), Teleprompter/Domain/AnswerPipeline.swift, TeleprompterTests/.
Arquivos permitidos: Teleprompter/Retrieval/* (novos), Teleprompter/Storage/* (se precisar), TeleprompterTests/Retrieval*Tests.swift (novos), docs/DATA.md (só detalhes do esquema SQLite). Não edite project.yml nem .github/.
Desenho:
- `LocalRetriever: Retriever` sobre SQLite3 do sistema (`import SQLite3`, sem dependência) com FTS5, tokenizador `unicode61 remove_diacritics 2` (pt-BR, acento não atrapalha). Banco em arquivo (URL injetada; testes usam diretório temporário).
- Indexação: `index(_ items: [IndexedChunk])` e `removeSource(_:)`, com `IndexedChunk { kind: .qa | .document | .code, text, source }`. Nota de Q&A indexa a pergunta esperada para casar e guarda a resposta preparada em `text`.
- Híbrido: pontuação lexical (FTS5 bm25 normalizada para 0...1) e, opcionalmente, similaridade por embedding atrás do protocolo `Embedder` (`embed(_:) -> [Float]`); entregue um `FakeEmbedder` determinístico para teste e deixe o embedder real para depois (ADR-0006). Funcione só com léxico quando `Embedder` for nil.
- Regra (ADR-0004 e 0009): consulta primeiro o Q&A; se a melhor nota tiver score >= `qaThreshold`, devolve `Retrieval(qaNote:, chunks: [])`. Senão devolve até `topK` trechos de documentos e código com score >= `chunkThreshold`. Se nenhum passa, devolve `Retrieval(qaNote: nil, chunks: [])`. Limiares e topK injetados no init, com padrões documentados.
- `Chunk.source` sempre preenchido com o caminho de origem.
- Pergunta vazia ou só de pontuação: resultado vazio, sem erro. Caracteres especiais do FTS5 na pergunta não podem quebrar a consulta (escape).
- Concorrência: escrita do índice em fila serial (Swift 6 sem warnings, tipo Sendable).
Faça: testes primeiro (corpus pequeno em pt-BR: pergunta casa nota de Q&A; casa só trecho de README; casa trecho de código; sem match devolve vazio; acento e caixa; pergunta com aspas e dois-pontos; reindex e removeSource; fontes preenchidas; limiares), depois o código. Rode xcodegen generate, swiftlint --strict e xcodebuild test (iPhone 17) até verde.
Regras: iOS 17.2+, Swift 6, sem dependência nova, sem texto de fala em log, comentário só quando o porquê não é óbvio.
Proibido: git commit/push/merge, gh, ler .env ou Keychain, editar .github/ e project.yml.
Entregue: resumo de 5 linhas do que mudou, limiares padrão escolhidos e resultado dos gates.
