# Dados — Teleprompter Meta

Dados locais do app. Ligado a [ARCHITECTURE.md](ARCHITECTURE.md) (parte Persistência) e a [TESTING.md](TESTING.md).

Status: aprovada em 2026-11-08 (revisão de 2026-11-08 aprovada)

## 1. Armazenamento
- Banco: sem servidor. SQLite com FTS5 e tabela de embeddings, gerado por `Tools/Indexer` (ADR-0006, proposta); configurações em arquivo local · Cache/fila: N/A · Arquivos: material importado e índice.
- Ambientes: local e iPhone; teste com diretório temporário por execução. Sem produção separada.

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
- Ferramenta: definir junto com o ADR de persistência. Índice é reconstruído em vez de migrado; Settings e QANote precisam de migração reversível se o esquema mudar.

## 5. Dados pessoais e LGPD
- Dados pessoais: nenhum de terceiros. A voz e o texto da pergunta podem sair para STT/LLM externo (registrar no ADR-005). Nenhuma transcrição em log.
- Retenção: Session guarda só métricas e é apagável. Conversation e Message ficam só no aparelho, apagáveis por conversa e em massa; nunca em log nem em backup externo. Voz não é gravada, só o texto.

## 6. Backup e recuperação
- Fonte de verdade das notas de Q&A: arquivos versionados no repositório de material. RPO/RTO: N/A. Restauração: reimportar.

## 7. Dados de teste
- Fixtures: áudios das 30 perguntas e corpus de Q&A, README e código de exemplo. Sem dado pessoal real.
