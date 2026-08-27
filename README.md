# Qasati-iOS

قاصتي — My Cash Vault: a native SwiftUI/SwiftData port of a local-first personal
finance app (originally a single-file HTML/JS app, `qasati-standalone_2.html`).
Arabic RTL throughout. All financial rules (validation, balance derivation,
edit/delete safety) live in `QasatiDomain`/`QasatiTransactionService`, never in
UI code.

## Modules (SwiftPM targets)

- `QasatiDomain` — transaction model, ledger math, amount validation. No dependencies.
- `QasatiPresentation` — currency formatting, shared presentation helpers. No dependencies.
- `QasatiPersistence` — SwiftData storage layer.
- `QasatiTransactionService` — add/edit/delete coordination between domain rules and persistence.
- `QasatiBackupService` — JSON export/import.
- `QasatiDashboardFeature`, `QasatiTransactionFormsFeature`, `QasatiHistoryFeature`, `QasatiSettingsFeature` — SwiftUI screens + view models.
- `QasatiSecurityFeature` — Face ID/Touch ID app-lock state machine, isolated from all financial data (zero dependencies on the targets above).

## Build & test

```sh
swift build
swift test
```

CI runs both on every push to `main` and via manual dispatch
(`.github/workflows/main.ymlphase1.yml`).

## Current status

Feature-complete SwiftPM core, verified by 181 automated tests passing in CI
with 0 failures and 0 warnings. **There is no Xcode App target yet** — the
screens, view models, and services above are not yet assembled into a runnable
iOS application.

## Known limitations (pending Xcode App integration)

- No app entry point, navigation, or shared `ModelContainer` wiring the four
  screens together.
- Settings' theme/privacy preferences are not yet connected to the
  Dashboard/History screens they're meant to affect.
- The app-lock state machine exists and is fully tested, but nothing yet
  triggers it from app launch/background lifecycle, and no real Face ID/Touch
  ID prompt has been exercised on a device.
- No VoiceOver, Dynamic Type, or on-device testing has been performed —
  Xcode/Simulator/a physical device are required for all of it.
