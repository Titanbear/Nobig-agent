# Mobile Client Skeleton Implementation Plan

**Goal:** Build an installable native Flutter Android client for a PC-hosted Agent, with an explicit demo and replaceable DSH transport.

**Architecture:** Flutter screens observe a controller which owns an AgentGateway. DSH networking and demo behavior implement the same interface. Only connection metadata and theme go into preferences; credentials go into platform secure storage.

**Tech Stack:** Flutter stable, Dart, Material 3, package:http, shared_preferences, flutter_secure_storage; dart:io for WebSocket.

## Task 1: Project and verification environment

- [x] Create the Android Flutter project in the existing repository on `codex/mobile-client-skeleton`.
- [x] Add `http`, `shared_preferences`, and `flutter_secure_storage`; retain flutter_test and flutter_lints.
- [x] Set Android label to Nobig Agent and enable network access. Use a separate local toolchain directory if Flutter is missing.

## Task 2: Connection domain and storage

Files: `lib/domain/models.dart`, `lib/data/settings_store.dart`, `test/connection_test.dart`.

- [x] Test URL normalization, reject malformed URLs and insecure public HTTP, and extract pasted launch tokens without persisting them in metadata.
- [x] Implement the connection and message types and secure/preference persistence.
- [x] Verify with `flutter test test/connection_test.dart`.

## Task 3: Gateway implementations

Files: `lib/data/agent_gateway.dart`, `lib/data/demo_gateway.dart`, `lib/data/dsh_gateway.dart`, `lib/data/dsh_transcript.dart`, `test/dsh_gateway_test.dart`, `test/dsh_transcript_test.dart`.

- [x] Build a local HTTP/WebSocket fixture which checks launch-token Cookie exchange, RPC envelope, same session IDs, stream snapshots, and cancel.
- [x] Test stream transcript replay and message deduplication before implementing the adapter.
- [x] Implement typed gateway operations. Send mutations once; reconnect only read subscriptions. Close sockets and timers when subscriptions end.
- [x] Implement explicit, in-memory demo mode with cancellable simulated output.

## Task 4: Native screens and controller

Files: `lib/app_controller.dart`, `lib/app.dart`, `lib/main.dart`, `lib/ui/connection_screen.dart`, `lib/ui/sessions_screen.dart`, `lib/ui/chat_screen.dart`, `lib/ui/settings_screen.dart`, `lib/ui/widgets.dart`, `test/app_test.dart`.

- [x] Test disconnected navigation and the demo create/send/stop flow on a narrow screen.
- [x] Implement the native shell, forms, empty states, chat composer, theme setting, and visible demo indicator.
- [x] Isolate connection generations so stale responses cannot update a replacement connection.
- [x] Resume read subscriptions on foreground; leave PC tasks running when leaving a page.

## Task 5: Delivery

Files: `README.md`, `docs/connection.md`, `.github/workflows/android.yml`.

- [x] Document actual startup commands, DSH compatibility, public address requirements, and current limitations.
- [x] Add CI for analysis, tests, and debug APK artifact, without embedding credentials.
- [x] Run `dart format`, `flutter analyze`, `flutter test`, and `flutter build apk --debug`.
- [x] Inspect Git diff and APK metadata; report verified results and any remaining real-device validation.
