# Backlog — Teleprompter Meta

Fonte das issues iniciais. `~/.claude/templates/criar-issues.sh` lê este arquivo e cria uma issue por bloco `## `. Depois de criadas, a issue no GitHub é a fonte; este arquivo vira histórico.

Formato do bloco: `## título`, linhas de metadado (`id:` nome curto, `labels: a, b`, `pai: id` vira sub-issue do pai, `depende: id1, id2` vira "bloqueada por"), corpo em Markdown. Id que não existe (bloco removido no perfil) é ignorado. Uma issue por história do [PRD](PRD.md) (título `US-01: ...`, critério de aceite copiado) mais as de fundação abaixo. Issue grande demais para um PR vira duas.

Status: aprovado. Aprovado em 2026-11-08

## epic: Fundação
id: fundacao
labels: epic

Base do projeto antes de qualquer feature: esteira, estratégia de testes, arquitetura, design system, protótipos e contratos. Sub-issues abaixo.

## epic: MVP
id: mvp
labels: epic
depende: fundacao

Histórias do PRD. Cada sub-issue é uma história com critério de aceite.

## chore(ci): esteira de CI e lefthook rodando
id: ci
labels: fundacao
pai: fundacao

Rodar cada passo do CI localmente, `lefthook install`, ligar o CI no GitHub e marcar como obrigatório no ruleset. Ver `~/.claude/templates/esteira/README.md`.

Aceite: PR de teste passa no CI; commit com segredo é barrado pelo hook.

## docs(testing): estratégia de testes aprovada
id: testing
labels: fundacao
pai: fundacao

Revisar `docs/TESTING.md` (matriz do perfil), ajustar por risco e registrar `aprovada em AAAA-MM-DD`.

Aceite: `docs/TESTING.md` sem marcador de pendência e com aprovação datada.

## docs(architecture): arquitetura e partes aprovadas
id: architecture
labels: fundacao
pai: fundacao

Fechar `docs/ARCHITECTURE.md` (partes, fluxos, riscos) e registrar `aprovada em AAAA-MM-DD`.

Aceite: `docs/ARCHITECTURE.md` sem marcador de pendência e com aprovação datada.

## docs(design): design system aprovado
id: design
labels: fundacao, design
pai: fundacao
depende: architecture

Preencher `DESIGN.md` (tokens, tipografia, componentes, acessibilidade, microcopy) e registrar aprovação.

Aceite: `DESIGN.md` sem marcador de pendência e com aprovação datada.

## docs(design): prototipar e aprovar as telas
id: telas
labels: fundacao, design
pai: fundacao
depende: design

Um protótipo por tela do inventário em `design/telas.md`, usando os tokens do `DESIGN.md`. Tela só vira issue de implementação depois de aprovada.

Aceite: toda tela do MVP com protótipo e data de aprovação em `design/telas.md`.

## docs(api): contrato da API e modelo de dados aprovados
id: api
labels: fundacao
pai: fundacao
depende: architecture

Preencher `docs/API.md` e `docs/DATA.md` e registrar aprovação.

Aceite: os dois docs sem marcador de pendência e com aprovação datada.

## US-01: Transcrever a fala em streaming
id: us-01
labels: feature
pai: mvp
depende: ci, testing, architecture

Como apresentador, quero transcrever a fala em streaming, para ter o texto da pergunta em tempo real.

Aceite: dado áudio gravado de uma pergunta em pt-BR, quando o pipeline roda, então a transcrição final tem WER abaixo de 15% (meta a validar).

## US-02: Detectar o fim da pergunta
id: us-02
labels: feature
pai: mvp
depende: us-01

Como apresentador, quero que o app detecte o fim da pergunta, para disparar a resposta sem tocar em nada.

Aceite: dado fala com pausa ao fim da pergunta, quando a pausa passa do limiar, então o app emite "pergunta completa" uma única vez.

## US-03: Buscar a resposta nas notas, README e código
id: us-03
labels: feature
pai: mvp
depende: ci, testing, architecture

Como apresentador, quero buscar a resposta nas minhas notas, README e código, para responder com base no meu material.

Aceite: dado uma pergunta que casa com uma nota de Q&A, quando a busca roda, então a nota é devolvida sem chamar o LLM.

## US-04: Resposta por LLM sem nota correspondente
id: us-04
labels: feature
pai: mvp
depende: us-03

Como apresentador, quero resposta por LLM quando não houver nota, para cobrir perguntas imprevistas.

Aceite: dado pergunta sem nota, quando o LLM responde, então o primeiro texto aparece em menos de 2 s (meta a validar) e usa só trechos recuperados como contexto.

## US-05: Formato da resposta configurável
id: us-05
labels: feature
pai: mvp
depende: us-04, telas

Como apresentador, quero escolher o formato da resposta, para ler no ritmo da situação.

Aceite: dado o formato "bullets curtos", quando a resposta é exibida, então respeita o limite de linhas e fonte da lente 600x600.

## US-06: Lente simulada no iPhone
id: us-06
labels: feature
pai: mvp
depende: us-05, telas

Como apresentador, quero uma lente simulada no iPhone, para desenvolver e ensaiar sem os óculos.

Aceite: dado o app no iPhone, quando uma resposta é gerada, então a view simulada exibe o mesmo conteúdo que iria para a lente.

## US-07: Tela de configurações
id: us-07
labels: feature
pai: mvp
depende: us-06, telas

Como apresentador, quero configurar formato, limiares e fontes de contexto, para ajustar o app a cada situação.

Aceite: dado a tela de configurações, quando altero uma opção, então ela persiste e vale na próxima pergunta.

## US-08: Resposta na lente real
id: us-08
labels: feature
pai: mvp
depende: us-06

Como apresentador, quero ver a resposta na lente real, para não olhar o celular.

Aceite: dado óculos pareados, quando uma resposta é gerada, então ela aparece no Display (fase 3).

## US-09: Pedir de novo ou pular por gesto
id: us-09
labels: feature
pai: mvp
depende: us-08

Como apresentador, quero pedir de novo ou pular a resposta por gesto, para controlar sem tocar no iPhone.

Aceite: dado o Neural Band, quando faço o gesto mapeado, então o app repete ou descarta a resposta (fase 4).

## US-10: Sessão estável por 60 minutos
id: us-10
labels: feature
pai: mvp
depende: us-09

Como apresentador, quero sessão estável por 60 min, para aguentar a banca inteira.

Aceite: dado uma sessão contínua, quando 60 min passam, então não há queda de conexão nem travamento não recuperado (fase 5).

## US-11: Importar e indexar o material
id: us-11
labels: feature
pai: mvp
depende: us-03, telas

Como apresentador, quero importar e indexar meu material, para a busca refletir o projeto atual.

Aceite: dado README, documentos, notas de Q&A e repositório, quando importo, então a busca passa a considerá-los.
