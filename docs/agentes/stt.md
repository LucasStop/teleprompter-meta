# Tarefa: STT em streaming, áudio de arquivo e harness de WER (issue #9, US-01)
Objetivo: transcrever em streaming em pt-BR e medir WER sobre perguntas gravadas.
Aceite (PRD): dado áudio gravado de uma pergunta em pt-BR, quando o pipeline roda, a transcrição final tem WER abaixo de 15% (meta a validar).
Leia antes: docs/PRD.md (US-01), docs/adr/0003-*.md, docs/API.md, docs/TESTING.md (linha Audio e STT), Teleprompter/Audio/AudioSource.swift, Teleprompter/STT/SpeechTranscriber.swift, Teleprompter/Domain/Models.swift (AudioBuffer, Transcript).
Arquivos permitidos: Teleprompter/Audio/*, Teleprompter/STT/*, TeleprompterTests/STT*Tests.swift, TeleprompterTests/Fixtures/ (novos), Tools/wer.swift ou Teleprompter/STT/WordErrorRate.swift, docs/TESTING.md (como rodar o harness). Não edite project.yml (se precisar de Info.plist keys de microfone e reconhecimento de fala, liste no resumo em vez de editar) nem .github/.
Desenho:
- `WordErrorRate`: função pura (distância de Levenshtein por palavra, normalizando caixa, pontuação e acento), com testes (iguais = 0, uma substituição, inserção, remoção, vazio).
- `FileAudioSource: AudioSource` lê um arquivo de áudio (AVAudioFile) e emite `AudioBuffer` em blocos, na taxa original; teste com um áudio curto gerado no teste (tom sintético) para checar blocos e fim do stream.
- `SpeechAnalyzerTranscriber: SpeechTranscriber` usando `SpeechAnalyzer` + `SpeechTranscriber` do framework Speech (iOS 26), locale pt-BR, resultados parciais e finais, atrás de `#available(iOS 26, *)`; no iOS 17.2 a 25 devolve stream vazio ou erro tipado `STTError.unavailable`. Consulte a API no SDK instalado (swiftinterface do Speech.framework no Xcode) porque o Apple docs não está disponível offline. Converta o formato do áudio para o que o analyzer pede.
- `AudioSource` do microfone do iPhone (`MicrophoneAudioSource`, AVAudioEngine) com a sessão configurada para HFP quando houver óculos; compile mas não teste em hardware.
- Harness de WER: um teste `WERHarnessTests` que, para cada `Fixtures/perguntas/NN.wav` com `NN.txt` de referência, transcreve e imprime o WER por arquivo e a média. Sem áudios na pasta, o teste faz `XCTSkip` com a mensagem de como gravar (as 30 perguntas serão gravadas pelo Lucas). Documente em docs/TESTING.md: gravar em 8 kHz mono, nome `NN.wav` e `NN.txt`.
- O teste de STT real nunca roda no CI (TESTING.md): marque com `XCTSkipUnless` de variável de ambiente `RUN_STT=1`.
Faça: testes primeiro (WER e FileAudioSource), depois o código. Rode xcodegen generate, swiftlint --strict e xcodebuild test (iPhone 17) até verde.
Regras: iOS 17.2+ (iOS 26 só com #available), Swift 6, sem dependência nova, sem texto de fala em log, comentário só quando o porquê não é óbvio.
Proibido: git commit/push/merge, gh, ler .env ou Keychain, editar .github/ e project.yml.
Entregue: resumo de 5 linhas do que mudou, chaves de Info.plist necessárias e resultado dos gates.
