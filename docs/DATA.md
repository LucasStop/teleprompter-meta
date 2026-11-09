# Dados — Teleprompter Meta

Dados locais do app. Ligado a [ARCHITECTURE.md](ARCHITECTURE.md) (parte Persistência) e a [TESTING.md](TESTING.md).

Status: aprovada em 2026-11-08 (revisão de 2026-11-08 aprovada)

## 1. Armazenamento
- Banco: sem servidor. SQLite com FTS5 e tabela de embeddings, gerado por `Tools/Indexer` (ADR-0006, proposta); configurações em arquivo local · Cache/fila: N/A · Arquivos: material importado e índice.
- Ambientes: local e iPhone; teste com diretório temporário por execução. Sem produção separada.

### Configurações e Segredos (`SettingsStore` e `SecretStore`)
- Configurações gerais (`SettingsStore`): armazenadas via `UserDefaultsSettingsStore` sob a chave `br.com.lucasstop.teleprompter.settings` como JSON codificado da struct `Settings` (incluindo `activeProjectId`, `llmProvider`, `llmBaseURL`, `llmModel` com decodificação retrocompatível via `decodeIfPresent`). Padrão de `activeProjectId`: `"default"`. Não contém segredos.
- Chave de API de LLM (`SecretStore`): armazenada exclusivamente no Keychain via `KeychainStore` sob a chave `llm.apiKey` (serviço `br.com.lucasstop.teleprompter`). Nunca gravada em `UserDefaults`, arquivos de log ou transitada em texto plano pela interface.

### Armazenamento de Projetos (`SQLiteProjectStore`)
- Banco: `Application Support/Teleprompter/projects.sqlite`
- Tabela `projects`:
  - `id TEXT PRIMARY KEY`: identificador único estável (`default` para o projeto padrão gerado na primeira execução).
  - `name TEXT NOT NULL`: nome legível do projeto.
  - `created_at REAL NOT NULL`: timestamp epoch da criação em segundos.
  - Índice: `idx_projects_name_nocase ON projects(name COLLATE NOCASE)` único para barrar nomes duplicados sem diferenciar maiúsculas/minúsculas.
- Regras de integridade:
  - Nome vazio ou contendo apenas espaços é recusado (`emptyName`).
  - Nome duplicado (case-insensitive) é recusado (`duplicateName`).
  - O projeto "Padrão" (`id: "default"`) é protegido contra exclusão (`cannotDeleteDefaultProject`), mas pode ser renomeado.

### Esquema SQLite do Índice Local (`LocalRetriever` e `ProductionAppRetriever`)
- Isolamento por projeto:
  - Cada projeto possui um banco SQLite isolado em `Application Support/Teleprompter/index-<projectId>.sqlite`.
  - Exceção retrocompatível: o projeto `default` continua usando o arquivo legado `retriever.sqlite` para manter intacto qualquer material previamente importado, sem necessidade de cópia ou migração.
  - Ao excluir um projeto, o arquivo `index-<projectId>.sqlite` correspondente é removido do disco.
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
- Tabela `conversations` (esquema `user_version = 2`):
  - `id TEXT PRIMARY KEY`: identificador único (UUID).
  - `project_id TEXT NOT NULL DEFAULT 'default'`: identificador do projeto ao qual a conversa pertence.
  - `title TEXT NOT NULL`: título curto derivado da primeira pergunta.
  - `created_at REAL NOT NULL`: timestamp epoch com precisão de milissegundos.
  - `updated_at REAL NOT NULL`: timestamp da última atualização para ordenação por mais recente.
  - Índices:
    - `idx_conversations_updated_at ON conversations(updated_at DESC)`.
    - `idx_conversations_project_updated_at ON conversations(project_id, updated_at DESC)`.
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
| Project | Agrupa material, índice isolado e histórico de conversas | id | tem índice próprio (`index-<id>.sqlite`) e Conversations | Não |
| Settings | Formato de resposta, limiares do detector, provedor/modelo/URL base de LLM, projeto ativo | única | referencia Project ativo | Não |
| MaterialSource | Fonte de material importada (Q&A, README, doc, código) | path | tem Chunks no LocalRetriever do projeto | Não |
| QANote | Pergunta esperada e resposta preparada | id | pertence a um Material | Não |
| Document | README e documentos importados | id | tem Chunks | Não |
| CodeFile | Arquivo do repositório indexado | caminho + commit | tem Chunks | Não |
| Chunk | Trecho indexado para busca | id | de Document ou CodeFile | Não |
| Conversation | Conversa do chat | id | pertence a um Project; tem Messages | Sim (texto das perguntas e respostas) |
| Message | Pergunta ou resposta, com fontes e latência | id | pertence a uma Conversation; cita Chunks | Sim |
| Session | Registro opcional de ensaio (latência por etapa, sem a fala) | id | - | Não |

### Formato de Notas Q&A (`MaterialImporter`)
O `MaterialImporter` reconhece dois formatos de notas de Q&A para indexação direta como `kind = .qa`:
1. **Formato P: / R:**
   - Prefixos de pergunta: `P:`, `Pergunta:`, `Q:`
   - Prefixos de resposta: `R:`, `Resposta:`, `A:`
   - Suporta respostas com múltiplas linhas e múltiplos pares por arquivo separados por linhas em branco.
2. **Formato Front Matter:**
   - Bloco delimitado por `---` contendo `pergunta: <texto>` ou `question: <texto>` e corpo como resposta preparada.

Arquivos de texto sem formato Q&A são quebrados via `MaterialChunker` por parágrafo/seção com sobreposição de contexto, classificados como `.code` (extensões de código como `.swift`, `.ts`, `.php`) ou `.document` (`.md`, `.txt`). Reimportação da mesma fonte substitui os trechos antigos atomicamente sem duplicar.

## 3. Regras de integridade
- Índice reconstruível a partir das fontes: pode ser descartado sem perda.
- Exclusão: restrita para QANote; Chunk some junto com a fonte.
- Concorrência: escrita do índice em uma fila serial.

## 4. Migrações
- **Projetos (`SQLiteProjectStore`)**: tabela criada na primeira execução com o projeto "Padrão" (`id: "default"`).
- **Índice de busca (`LocalRetriever` / `ProductionAppRetriever`)**: descartável e reconstruído a partir das fontes (sem migração). Cada projeto tem seu arquivo `index-<projectId>.sqlite`, exceto `default` que mantém `retriever.sqlite`.
- **Conversas e mensagens (`SQLiteConversationStore`)**: versionado por `PRAGMA user_version`.
  - **Versão 1**: criação das tabelas `conversations` e `messages` e seus índices (`idx_conversations_updated_at`, `idx_messages_conversation`) com chave estrangeira e deleção em cascata (`ON DELETE CASCADE`).
  - **Versão 2**: adição da coluna `project_id TEXT NOT NULL DEFAULT 'default'` na tabela `conversations` e do índice composto `idx_conversations_project_updated_at ON conversations(project_id, updated_at DESC)`.
  - **Estratégia reversível**: cada versão implementa `migrate(to:)` e `rollback(to:)`.
    - Rollback 2 -> 1: remove o índice `idx_conversations_project_updated_at`, remove a coluna `project_id` via `ALTER TABLE conversations DROP COLUMN project_id` e redefine `user_version = 1`, preservando todas as conversas e mensagens existentes.
    - Rollback 1 -> 0: descarta as tabelas `messages` e `conversations` e redefine `user_version = 0`.
- **Configurações e Q&A**: Settings e QANote usam migração reversível se o esquema em arquivo mudar (campo `activeProjectId` com `decodeIfPresent`).

## 5. Dados pessoais e LGPD
- Dados pessoais: nenhum de terceiros. A voz e o texto da pergunta podem sair para STT/LLM externo (registrar no ADR-005). Nenhuma transcrição em log.
- Retenção: Session guarda só métricas e é apagável. Conversation e Message ficam só no aparelho, apagáveis por conversa e em massa; nunca em log nem em backup externo. Voz não é gravada, só o texto.

## 6. Backup e recuperação
- Fonte de verdade das notas de Q&A: arquivos versionados no repositório de material. RPO/RTO: N/A. Restauração: reimportar.

## 7. Dados de teste
- Fixtures: áudios das 30 perguntas e corpus de Q&A, README e código de exemplo. Sem dado pessoal real.
