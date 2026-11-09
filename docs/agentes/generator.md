# Tarefa: AnswerGenerator com streaming e chave no Keychain (issue #12, US-04)
Objetivo: gerar a resposta por LLM em streaming a partir só dos trechos recuperados (RAG fechado), sem fixar provedor.
Aceite (PRD): dado pergunta sem nota correspondente, quando o LLM responde, o primeiro texto aparece em menos de 2 s (meta a validar) e usa só trechos recuperados como contexto.
Leia antes: docs/PRD.md (US-04, US-13), docs/adr/0005-*.md, 0009-*.md, docs/API.md, Teleprompter/LLM/AnswerGenerator.swift, Teleprompter/Domain/Models.swift, Teleprompter/Domain/AnswerPipeline.swift, TeleprompterTests/Fakes.swift.
Arquivos permitidos: Teleprompter/LLM/* (novos), Teleprompter/Storage/KeychainStore.swift (novo), TeleprompterTests/LLM*Tests.swift e KeychainTests.swift (novos), docs/API.md (seção do contrato com o provedor). Não edite project.yml nem .github/.
Desenho:
- `StreamingAnswerGenerator: AnswerGenerator` faz POST HTTPS em streaming (SSE, `URLSession.bytes(for:)`) para um endpoint compatível com a API de chat completions; `baseURL`, `model`, `timeout` e `URLSession` injetados (nenhum provedor hardcoded; ADR-0005 está em aberto). Chave lida de um `SecretStore` (protocolo) via header Authorization Bearer; nunca em log, URL ou mensagem de erro.
- Prompt de sistema em pt-BR: responder só com os trechos fornecidos, curto, em tópicos; se os trechos não bastarem, dizer "Não encontrei isso no seu material". Contexto = os `Chunk` com a fonte. Sem trechos, não chama a rede e devolve o stream vazio (RAG fechado).
- Emite os deltas de texto à medida que chegam (`AsyncStream<String>`); cancelar a Task cancela a requisição. Erros tipados `LLMError` (sem chave, rede, HTTP status, resposta inválida) sem vazar a chave nem o texto da pergunta.
- `KeychainStore: SecretStore` (Security.framework, kSecClassGenericPassword, serviço `br.com.lucasstop.teleprompter`) com `get/set/delete`; testes usam um `InMemorySecretStore` fake. Teste do Keychain real só se rodar no simulador sem prompt; senão cubra via protocolo.
- Testes de rede com `URLProtocol` fake: deltas em ordem, fim do stream, cancelamento, HTTP 401/500, JSON inválido, sem chave, sem trechos (nenhuma requisição feita), e que o corpo enviado contém os trechos e a pergunta mas o header/erros não contêm a chave.
Faça: testes primeiro, depois o código. Rode xcodegen generate, swiftlint --strict e xcodebuild test (iPhone 17) até verde.
Regras: iOS 17.2+, Swift 6, sem dependência nova, sem texto de fala em log, comentário só quando o porquê não é óbvio.
Proibido: git commit/push/merge, gh, ler .env ou Keychain real do usuário, editar .github/ e project.yml.
Entregue: resumo de 5 linhas do que mudou e do resultado dos gates.
