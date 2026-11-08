# ADR 0001 — Swift nativo com Meta DAT SDK

- Status: aceita
- Data: 2026-11-08

## Contexto
O app precisa falar com o Meta Ray-Ban Display (microfone, display, gestos do Neural Band) e rodar em iPhone físico com latência mínima. O Meta Wearables Device Access Toolkit (DAT) tem módulos iOS em Swift Package Manager.

## Decisão
App iOS nativo em Swift/SwiftUI usando o DAT SDK (MWDATCore, MWDATCamera, MWDATDisplay), isolado no módulo Glasses.

## Alternativas consideradas
- Cross-platform (Flutter, React Native): sem suporte do DAT SDK e com latência extra.
- Web App: sem acesso a Bluetooth HFP nem ao SDK.

## Consequências
- Positivas: acesso direto ao SDK e às APIs de fala da Apple, menor latência.
- Negativas e riscos: SDK em developer preview; exige iOS 17.2+ e Xcode 26.4+.
- Impacto em testes e design: Mock Device Kit não cobre display nem microfone; usar lente simulada e áudios gravados.
