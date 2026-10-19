# SmartBroker

An AI-assisted, contact-centric CRM for brokers, built with Flutter (Android-first).

Write a quick note after a call or meeting and SmartBroker turns it into a clean
summary, a list of action items, and a follow-up reminder — all linked to the contact.
On Android it can also detect phone calls, log them automatically, and prompt you
to take notes while the conversation is still fresh.

---

## Status

| Area | State |
|---|---|
| UI (home, contacts, calendar, tasks, notes, settings) | Working |
| Local database (SQLite) + repositories | Working — demo data is seeded on first launch |
| Phone-book import / merge | Working |
| AI note analysis | Working — OpenAI-compatible providers (Groq by default) |
| Reminder notifications | Working |
| Call detection + auto call log (Android) | Working, needs device testing |
| Live call overlay (Android) | Working, needs device testing |

---

## Features

- **Home** — greeting, stats, upcoming reminders, recent contacts, pending tasks.
- **Contacts** — SmartBroker contacts merged with the device phone book, search and
  filters (All / Recent / Has Tasks / Overdue). Phone-only contacts can be added to SmartBroker.
- **Contact detail** — notes timeline, tasks, call history, reminders.
- **Notes → AI Review** — write a note, the AI proposes a summary, action items and a
  reminder; edit anything and save it to the contact.
- **Tasks** — all tasks across contacts with filters, sorting and bulk actions.
- **Calendar** — month view with reminder dots, reminder detail/edit, local notifications.
- **Call detection (Android)** — foreground service watches call state, reads the call
  log when a call ends, matches the number to a contact, logs it, and sends a
  "Tap to add a note" notification.
- **Call overlay (Android)** — floating panel during a call for taking notes; drafts auto-save.
- **Settings** — AI provider / key / model, call detection options, and a
  "Simulate Call" debug tool.

---

## AI setup

The app talks to any OpenAI-compatible chat-completions API. Pick a provider in
**Settings → AI Integration**, paste a key and tap **Save** (the key is validated first).

| Provider | Default model | Get a key |
|---|---|---|
| **Groq** (default, free tier, no card) | `openai/gpt-oss-20b` | console.groq.com/keys |
| OpenRouter (free `:free` models) | `openai/gpt-oss-120b:free` | openrouter.ai/keys |
| NVIDIA NIM | `meta/llama-3.1-8b-instruct` | build.nvidia.com |

Free tiers and model IDs change often. If a model stops working, type a new model ID
into the **Model** field — no app update needed. Keys are stored with
`flutter_secure_storage`, one per provider.

Providers are defined in `lib/core/services/ai_provider.dart`.

---

## Tech stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Material 3), Dart ≥ 3.11 |
| Storage | `sqflite` (data), `shared_preferences` (settings), `flutter_secure_storage` (API keys) |
| AI | OpenAI-compatible HTTP API via `http` |
| Notifications | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Contacts | `flutter_contacts` |
| Call overlay | `flutter_overlay_window` |
| Native | Kotlin `CallDetectionService` + `CallDetectionPlugin` (Method/Event channels) |
| UI | `google_fonts` (Inter), `lucide_icons`, `table_calendar`, `intl` |
| State | Local `StatefulWidget` + repositories |

---

## Project structure

```
lib/
├── main.dart                 # App entry, routes, overlay entry point (overlayMain)
├── core/
│   ├── constants/            # Named routes
│   ├── database/             # DatabaseHelper (schema), SeedData (demo data)
│   ├── repositories/         # Contact, Note, Todo, Reminder, Call repositories
│   ├── services/             # AI, API keys, settings, notifications, contacts merge,
│   │                         #   call detection/matching, overlay drafts
│   ├── theme/                # AppTheme, AppColors, AppSpacing, AppRadius
│   └── widgets/              # Shared UI components
├── features/
│   ├── calendar/             # Calendar, reminder detail
│   ├── calls/                # Live call overlay
│   ├── contacts/             # Contacts list, contact detail, phone-contact detail
│   ├── home/                 # Main shell (bottom nav), home dashboard
│   ├── notes/                # Add note, AI review, note detail, notes list
│   ├── settings/             # Settings
│   └── todos/                # Tasks
├── mock/                     # Demo data used by SeedData on first launch
└── models/                   # Domain models
android/app/src/main/kotlin/… # CallDetectionService.kt, CallDetectionPlugin.kt
test/                         # Unit + repository tests (in-memory SQLite via sqflite_common_ffi)
```

### Data model

`contacts` 1—* `notes`, `todos`, `reminders`, `calls`. Todos and reminders can link
back to the note that created them (`noteId`). Deleting a contact cascades.

- **Schema version 2** (`lib/core/database/schema.dart`). Fresh installs create it directly;
  older databases are upgraded by the steps in `lib/core/database/migrations.dart`, inside
  one transaction. Add a new `Migration` and bump `schemaVersion` for every schema change, and
  never edit a released one. `test/core/database/migration_test.dart` checks that an upgraded
  v1 database ends up identical to a fresh one.
- **One contact per number:** `contacts.phoneKey` (last 9 digits) has a unique index. The v2
  migration merged existing duplicates, and `ContactRepository.insert` returns the existing
  contact's id instead of creating a second one.
- Open-task counts are computed in queries, not stored. Calls are stored once per contact and
  start time. `todos.dueAt` and the `unassigned_calls` table are ready for due dates and the
  unknown-caller inbox.

---

## Running locally

```bash
flutter pub get
flutter run          # Android device or emulator (the only supported target besides iOS scaffolding)
flutter analyze
flutter test --coverage
dart format lib test   # page width 120, see analysis_options.yaml
```

Repository tests run against an in-memory SQLite database (`test/helpers/test_db.dart`),
so they don't need a device. Use fictional names and numbers in tests.
`test/features/large_text_layout_test.dart` lays out key screens on a small phone with large
text and fails on any overflow.

### CI

`.github/workflows/ci.yml` runs on every push and pull request: format check →
`flutter analyze --fatal-infos` → `flutter test --coverage` → coverage gate
(`tool/coverage_gate.sh`, 50 % for now) → dead-handler scan (`tool/no_dead_handlers.sh`:
no empty `onTap`/`onPressed`, no `print`) → debug APK, uploaded as a build artifact. A weekly workflow posts
`flutter pub outdated` to an issue. Protect `main` by requiring the `flutter` job.

On Windows without a terminal, `tool/dev_runner.bat` runs a fixed set of these commands
when asked (`build_logs/request.txt` → `build_logs/result.log`); `emubuild` makes a smaller,
x86_64-only debug APK for the emulator. `tool/emulator.bat` starts the Android Studio emulator,
installs the debug APK and opens the app; `tool/emu_bridge.bat` accepts a few fixed commands
(screenshot, tap, swipe, type, keys, Flutter log, font size, display size, free space, reinstall,
connected devices, Addis Scribe trial) for remote demos and UI checks. `tool/scribe/` holds the
offline-transcription spike: an Android build script for NeMo-Speech.cpp, the on-device benchmark
and an accuracy check for your own Amharic voice notes (see the research note in `docs/research/`). Debug builds log the full Flutter error report, so an overflow
in the log names the widget and source line.

Call detection and the overlay only work on a real Android device. Use
**Settings → Developer Tools → Simulate Call** to test the call-logging flow without one.

> After changing enums or `main.dart`, use hot restart (`R`), not hot reload.

Debug builds fill an empty database with fictional demo data (also available via
Settings → Developer Tools → Load demo data). Release builds start empty.

Release builds and signing: see [docs/RELEASE.md](docs/RELEASE.md).

---

## Known issues / next up

- Call detection only works while the app process is alive (open or in the background);
  if Android kills the app, calls aren't detected until it's opened again.
- The call overlay can't bring the app to the front. After "Save & Process", open
  SmartBroker (or tap the post-call notification) and AI Review opens automatically.
- For outgoing calls the caller's name appears in the overlay only when the call ends.
- Unknown numbers are auto-created as contacts (an "unassigned calls" inbox is planned; its
  table already exists). A number can belong to only one contact.
  By default the live overlay and the post-call prompt only appear for numbers that are
  already contacts (Settings → Live call overlay: Contacts / All calls / Off).
- The home greeting name is hardcoded.

---

## License

MIT © SmartBroker
