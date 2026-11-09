# PRD — Teleprompter Meta

App iOS pessoal em formato de chat: pergunto por voz ou texto, ele busca só no material que eu inseri (RAG) e responde no chat e, em resumo, na lente do Meta Ray-Ban Display, como teleprompter com contexto.

Plano de origem: documento "Teleprompter com IA para Ray-Ban Display" (claude.ai, abas Plano e ADRs) e handoff de 2026-11-08.

## Problem Statement
Em apresentações, palestras e na defesa do projeto diante da banca, as perguntas chegam sem aviso e a resposta precisa vir rápida e correta. Olhar anotações ou o celular quebra o contato com a banca. Teleprompter comum só rola um roteiro fixo e não reage à pergunta feita.

## Solution
App iOS com tela de chat (mensagens, campo de texto e microfone). A pergunta entra por texto, por toque no microfone ou pela escuta contínua da banca; o app responde apenas com base no material importado e, se nada relevante for achado, diz que não achou em vez de inventar. No modo de escuta contínua, ele captura o áudio pelo microfone dos óculos (Bluetooth HFP), transcreve em streaming, detecta o fim da pergunta, busca nas minhas notas de Q&A, no README e documentos e no código do repositório, e exibe na lente uma resposta curta no formato escolhido (bullets, palavras-chave ou texto completo). Se a pergunta casar com uma nota de Q&A, a resposta sai direto; senão um LLM rápido gera a resposta com streaming. Gesto no Neural Band pede de novo ou pula.

## User Stories
Cada história tem critério de aceite, que vira teste (ver [TESTING.md](TESTING.md), seção Rastreabilidade).
Telas em [../design/telas.md](../design/telas.md). As metas numéricas são propostas, a validar nos protótipos P1 a P4 (fase 1).

| ID | História | Critério de aceite (dado / quando / então) | Status de implementação |
|---|---|---|---|
| US-01 | Como apresentador, quero transcrever a fala em streaming, para ter o texto da pergunta em tempo real | Dado áudio gravado de uma pergunta em pt-BR, quando o pipeline roda, então a transcrição final tem WER abaixo de 15% (meta a validar) | Parcial (componentes e harness implementados; falta validação de WER < 15% com 30 gravações humanas do Lucas e asset pt-BR em iPhone físico). Testes: `STTTranscriberTests.swift`, `STTFileAudioSourceTests.swift`, `STTWordErrorRateTests.swift`, `WERDatasetDiscovery.swift`, `STTWERHarnessTests.swift` |
| US-02 | Como apresentador, quero que o app detecte o fim da pergunta, para disparar a resposta sem tocar em nada | Dado fala com pausa ao fim da pergunta, quando a pausa passa do limiar configurado, então o app emite "pergunta completa" uma única vez | Implementada e coberta por teste: `QuestionDetectorTests.swift` |
| US-03 | Como apresentador, quero buscar a resposta nas minhas notas, README e código, para responder com base no meu material | Dado uma pergunta que casa com uma nota de Q&A, quando a busca roda, então a nota é devolvida sem chamar o LLM | Implementada e coberta por teste: `RetrievalTests.swift`, `AnswerPipelineTests.swift`, `RetrievalBenchmarkTests.swift` |
| US-04 | Como apresentador, quero resposta por LLM quando não houver nota, para cobrir perguntas imprevistas | Dado pergunta sem nota correspondente, quando o LLM responde, então o primeiro texto aparece em menos de 2 s (meta a validar) e usa só trechos recuperados como contexto | Parcial (pipeline SSE implementado com fakes; falta decisão do Lucas no ADR-0005 sobre provedor de LLM e medição com rede real). Testes: `LLMStreamingAnswerGeneratorTests.swift`, `LLMAnthropicTests.swift`, `AnswerPipelineTests.swift`, `LLMBenchmarkTests.swift` |
| US-05 | Como apresentador, quero escolher o formato da resposta, para ler no ritmo da situação | Dado o formato "bullets curtos", quando a resposta é exibida, então respeita o limite de linhas e fonte da lente 600x600 | Implementada e coberta por teste: `LensFormatterTests.swift`, `DesignSystemTokensTests.swift`, `SettingsViewModelTests.swift` |
| US-06 | Como apresentador, quero uma lente simulada no iPhone, para desenvolver e ensaiar sem os óculos | Dado o app no iPhone, quando uma resposta é gerada, então a view simulada exibe o mesmo conteúdo que iria para a lente | Implementada e coberta por teste: `LensViewTests.swift`, `ChatViewTests.swift`, `EnsaioViewModelTests.swift` |
| US-07 | Como apresentador, quero configurar formato, limiares, fontes de contexto e provedor de LLM, para ajustar o app a cada situação | Dado a tela de configurações, quando altero uma opção ou autentico um provedor, então ela persiste e vale na próxima pergunta | Implementada e coberta por teste: `SettingsStoreTests.swift`, `SettingsViewModelTests.swift`, `KeychainTests.swift`, `OpenRouterAuthServiceTests.swift`, `AppEnvironmentIntegrationTests.swift` |
| US-08 | Como apresentador, quero ver a resposta na lente real, para não olhar o celular | Dado óculos pareados, quando uma resposta é gerada, então ela aparece no Display (fase 3) | Depende de hardware (Meta Ray-Ban Display, fase 3) e integração do DAT SDK (`GlassesLens`) |
| US-09 | Como apresentador, quero pedir de novo ou pular a resposta por gesto, para controlar sem tocar no iPhone | Dado o Neural Band, quando faço o gesto mapeado, então o app repete ou descarta a resposta (fase 4) | Depende de hardware (Meta Neural Band, fase 4) e gestos no DAT SDK |
| US-10 | Como apresentador, quero sessão estável por 60 min, para aguentar a banca inteira | Dado uma sessão contínua, quando 60 min passam, então não há queda de conexão nem travamento não recuperado (fase 5) | Depende de hardware e teste de campo (fase 5) |
| US-11 | Como apresentador, quero importar e indexar meu material (arquivo único ou pasta inteira), para a busca refletir o projeto atual | Dado README, documentos, notas de Q&A e repositório/pasta, quando importo, então a busca passa a considerá-los sem duplicar | Implementada e coberta por teste: `MaterialImporterTests.swift`, `MaterialChunkerTests.swift`, `FolderScannerTests.swift`, `MaterialViewModelTests.swift`, `MaterialFolderViewModelTests.swift`, `MaterialIntegrationTests.swift` |
| US-12 | Como apresentador, quero conversar por texto ou por toque no microfone, para usar o app também fora da banca | Dado o chat aberto, quando envio texto ou falo após tocar no microfone, então a pergunta aparece como mensagem e recebe resposta pelo mesmo pipeline | Implementada e coberta por teste: `ChatScreenStateTests.swift`, `ChatViewTests.swift`, `ConversationViewModelTests.swift`, `ConversationAudioTests.swift`, `AppEnvironmentIntegrationTests.swift` |
| US-13 | Como apresentador, quero que o app responda só com o meu material, para não ouvir invenção na banca | Dado uma pergunta sem trecho acima do limiar de similaridade, quando a busca roda, então o app responde "Não encontrei isso no seu material" sem chamar o LLM livre; toda resposta mostra as fontes usadas | Implementada e coberta por teste: `AnswerPipelineTests.swift`, `RetrievalTests.swift`, `ConversationViewModelTests.swift`, `AppEnvironmentIntegrationTests.swift` |
| US-14 | Como apresentador, quero conversas salvas no aparelho, para revisar e ensaiar depois | Dado conversas anteriores, quando abro "Conversas", então vejo a lista por mais recente e posso abrir ou apagar cada uma | Implementada e coberta por teste: `ConversationStoreTests.swift`, `ConversationsViewModelTests.swift`, `AppEnvironmentIntegrationTests.swift` |

## Implementation Decisions
- Plataforma e stack: Swift nativo, SwiftUI, iOS 17.2+, Xcode 26.4+, Meta Wearables Device Access Toolkit (módulos MWDATCore, MWDATCamera, MWDATDisplay via Swift Package Manager), testado em iPhone físico. ADR-0001.
- Partes do sistema: ver [ARCHITECTURE.md](ARCHITECTURE.md).
- Cada etapa do pipeline é um protocolo Swift com implementação para iPhone/simulada e outra para os óculos; o DAT SDK fica isolado no módulo Glasses.
- Chat como interface principal: três entradas (texto, toque no microfone, escuta contínua com detecção de fim de pergunta). A lente sempre espelha a última resposta.
- RAG fechado: o LLM só recebe trechos recuperados do material inserido; sem trecho acima do limiar, não há resposta livre (ADR-0009 a criar).
- Disparo automático na escuta contínua, mais gesto para pedir de novo ou pular.
- Prioridade técnica: latência mínima.
- Fases 0 a 7 com gates G0 a G6; a compra do Display fica no gate G1, depois dos protótipos.

## Design Decisions
- Design system: [../DESIGN.md](../DESIGN.md). Telas e aprovação: [../design/telas.md](../design/telas.md).
- Lente do Display: 600x600 px; formato da resposta configurável.
- UI do iPhone em pt-BR. Tema do app claro/escuro automático (segue o sistema); a lente é sempre escura. Detalhes no DESIGN.md.

## Testing Decisions
- Estratégia e matriz por parte: [TESTING.md](TESTING.md).
- Bom teste aqui roda sem óculos: áudios gravados das 30 perguntas da banca, fakes dos protocolos e lente simulada. O Mock Device Kit não simula display nem microfone.
- Mais peso em: detecção de fim de pergunta, busca/recuperação, formatação por tamanho de lente e latência ponta a ponta.

## Out of Scope
- Publicação na App Store, outros usuários, Android, Web App e servidor próprio.
- Dado pessoal de terceiros.
- Resposta com conhecimento geral fora do material (decisão de 2026-11-08: RAG fechado).

## Further Notes
- DAT SDK em developer preview; acesso ao display aberto em 2026-05-14. O Ray-Ban Display não é vendido no Brasil e o Developer Center completo é só para países suportados: validar antes de comprar.
- SpeechAnalyzer (iOS 26) não tem vocabulário customizado como o contextualStrings do SFSpeechRecognizer.
- Banca em novembro de 2027 (cerca de 12 meses de folga para as fases 0 a 7).
- A banca permite auxílio: dos colegas, e do documento exibido nos óculos. O risco de proibição deixa de existir.
- Tudo em português (perguntas, respostas e UI): STT e busca só em pt-BR, sem requisito de termos em inglês.
- Questão em aberto: provedor de LLM (ADR-0005, sai do protótipo P1).
