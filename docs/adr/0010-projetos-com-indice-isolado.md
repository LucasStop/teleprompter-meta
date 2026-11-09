# ADR 0010 — Projetos com índice isolado por arquivo SQLite

- Status: aceita em 2026-11-09 (Lucas)
- Data: 2026-11-09

## Contexto
O usuário precisa alternar entre múltiplos assuntos ou bancas (ex.: "Plataforma de cursos" e "Teleprompter Meta"). Cada projeto deve possuir seu próprio conjunto de materiais e seu histórico isolado de conversas, garantindo que o RAG fechado (ADR-0009) nunca vaze trechos ou notas de um projeto em outro.

Além disso, a base já importada no projeto padrão não pode sofrer migração custosa nem risco de perda de dados.

## Decisão
1. **Índice isolado por arquivo**: cada projeto mantém sua própria base SQLite de busca local (`index-<projectId>.sqlite` em `Application Support/Teleprompter/`). O projeto padrão (`default`) herda o arquivo `retriever.sqlite` existente, eliminando necessidade de cópias ou migração de trechos existentes.
2. **Ponto único de resolução**: `ProductionAppRetriever` resolve a instância de `LocalRetriever` correspondente ao `activeProjectId` mantido no `SettingsStore` (com cache por projeto e limiares). A troca de projeto reconfigura imediatamente Chat, Ensaio e Material sem reiniciar o app.
3. **Exclusão atômica**: apagar um projeto apaga fisicamente o arquivo do índice (`index-<projectId>.sqlite` e seus arquivos auxiliares `-wal`/`-shm`) e as conversas daquele projeto (`DELETE FROM conversations WHERE project_id = ?`). O projeto `default` é protegido contra exclusão.
4. **Conversas por projeto**: a tabela `conversations` recebe a coluna `project_id TEXT NOT NULL DEFAULT 'default'` através de migração `user_version` 1 para 2 reversível. As operações de listagem, salvamento e remoção filtram pelo projeto ativo.

## Alternativas descartadas
- **Tabela única com coluna `project_id` para chunks e FTS5**: exigiria migrar a tabela legada `retriever.sqlite`, refazer índices FTS5 com filtros adicionais por projeto e traria risco de vazamento acidental se um filtro falhasse em queries complexas. A exclusão de projeto exigiria `DELETE` em massa e `VACUUM` pesado em vez de um simples `removeItem(at:)`.

## Consequências
- **Positivas**:
  - Isolamento físico absoluto: garantia estrita de que perguntas no projeto A jamais recuperam fontes do projeto B.
  - Zero risco de regressão nos dados do projeto padrão (`retriever.sqlite` permanece inalterado).
  - Exclusão limpa e instantânea de material via remoção de arquivo no sistema de arquivos.
- **Negativas e riscos**:
  - Múltiplas conexões SQLite em cache no `ProductionAppRetriever` (mitigado por fechamento e remoção de cache no delete).
  - Necessidade de gerenciar nomes e identificadores estáveis de projeto em `projects.sqlite`.
