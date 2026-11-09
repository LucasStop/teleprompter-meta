# Dados — Teleprompter Meta

Dados locais do app. Ligado a [ARCHITECTURE.md](ARCHITECTURE.md) (parte Persistência) e a [TESTING.md](TESTING.md).

Status: aprovada em 2026-11-08 (revisão de 2026-11-08 aprovada)

## 1. Armazenamento
- Banco: sem servidor. SQLite com FTS5 e tabela de embeddings, gerado por `Tools/Indexer` (ADR-0006, proposta); configurações em arquivo local · Cache/fila: N/A · Arquivos: material importado e índice.
- Ambientes: local e iPhone; teste com diretório temporário por execução. Sem produção separada.

### Esquema SQLite do Índice Local (`LocalRetriever`)
- Tabela `chunks`:
  - `id INTEGER PRIMARY KEY AUTOINCREMENT`: chave primária interna do trecho.
  - `kind TEXT NOT NULL`: tipo do trecho (`qa`, `document`, `code`).
  - `source_path TEXT NOT NULL`: caminho da fonte de origem (`SourceRef.path`).
  - `text TEXT NOT NULL`: texto do trecho ou resposta preparada da nota de Q&A.
  - `search_text TEXT NOT NULL`: texto indexado para busca (pergunta esperada no Q&A; texto em documentos e código).
  - `embedding BLOB`: vetor serializado `[Float]` para similaridade semântica opcional.
  - Índice: `idx_chunks_source ON chunks(source_path)` para deleção rápida por fonte.
- Tabela virtual FTS5 `chunks_fts`:
  - `search_text`: texto indexado lexicalmente.
  - Tokenizador: `unicode61 remove_diacritics 2` (ignora diacríticos/acentos e caixa em pt-BR).
  - Associação: `rowid` alinhado ao `id` da tabela `chunks`.

### Esquema SQLite do Armazenamento de Conversas (`SQLiteConversationStore`)
- Tabela `conversations`:
  - `id TEXT PRIMARY KEY`: identificador único (UUID).
  - `title TEXT NOT NULL`: título curto derivado da primeira pergunta.
  - `created_at REAL NOT NULL`: timestamp epoch com precisão de milissegundos.
  - `updated_at REAL NOT NULL`: timestamp da última atualização para ordenação por mais recente.
  - Índice: `idx_conversations_updated_at ON conversations(updated_at DESC)`.
- Tabela `messages`:
  - `id TEXT PRIMARY KEY`: identificador único (UUID).
  - `conversation_id TEXT NOT NULL`: chave estrangeira referenciando `conversations(id)` com `ON DELETE CASCADE`.
  - `role TEXT NOT NULL`: papel da mensagem (`question` ou `answer`).
  - `text TEXT NOT NULL`: conteúdo em texto da pergunta ou resposta (voz nunca é gravada).
  - `sources TEXT NOT NULL`: lista serializada em JSON das fontes citadas (`[String]`).
  - `latency_ms INTEGER`: latência total da resposta em milissegundos (nulo para perguntas).
  - `created_at REAL NOT NULL`: timestamp epoch da mensagem para ordenação cronológica.
  - Índice: `idx_messages_conversation ON messages(conversation_id, created_at ASC)`.

## 2. Entidades

| Entidade | Responsabilidade | Chave | Relações | Dado pessoal? |
|---|---|---|---|---|
| Settings | Formato de resposta, limiares do detector, fontes ativas | única | - | Não |
| QANote | Pergunta esperada e resposta preparada | id | pertence a um Material | Não |
| Document | README e documentos importados | id | tem Chunks | Não |
| CodeFile | Arquivo do repositório indexado | caminho + commit | tem Chunks | Não |
| Chunk | Trecho indexado para busca | id | de Document ou CodeFile | Não |
| Conversation | Conversa do chat | id | tem Messages | Sim (texto das perguntas e respostas) |
| Message | Pergunta ou resposta, com fontes e latência | id | pertence a uma Conversation; cita Chunks | Sim |
| Session | Registro opcional de ensaio (latência por etapa, sem a fala) | id | - | Não |

## 3. Regras de integridade
- Índice reconstruível a partir das fontes: pode ser descartado sem perda.
- Exclusão: restrita para QANote; Chunk some junto com a fonte.
- Concorrência: escrita do índice em uma fila serial.

## 4. Migrações
- **Índice de busca (`LocalRetriever`)**: descartável e reconstruído a partir das fontes (sem migração).
- **Conversas e mensagens (`SQLiteConversationStore`)**: versionado por `PRAGMA user_version`.
  - **Versão 1**: criação das tabelas `conversations` e `messages` e seus índices (`idx_conversations_updated_at`, `idx_messages_conversation`) com chave estrangeira e deleção em cascata (`ON DELETE CASCADE`).
  - **Estratégia reversível**: cada versão implementa `migrate(to:)` e `rollback(to:)`. A reversão para versão 0 descarta as tabelas e índices criados e redefine `user_version = 0`.
- **Configurações e Q&A**: Settings e QANote usam migração reversível se o esquema em arquivo mudar.

## 5. Dados pessoais e LGPD
- Dados pessoais: nenhum de terceiros. A voz e o texto da pergunta podem sair para STT/LLM externo (registrar no ADR-005). Nenhuma transcrição em log.
- Retenção: Session guarda só métricas e é apagável. Conversation e Message ficam só no aparelho, apagáveis por conversa e em massa; nunca em log nem em backup externo. Voz não é gravada, só o texto.

## 6. Backup e recuperação
- Fonte de verdade das notas de Q&A: arquivos versionados no repositório de material. RPO/RTO: N/A. Restauração: reimportar.

## 7. Dados de teste
- Fixtures: áudios das 30 perguntas e corpus de Q&A, README e código de exemplo. Sem dado pessoal real.
