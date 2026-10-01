# 05 — Test strategy and test plan

## 7.3.1 Current testing assessment [Verified]

- **Framework:** `flutter_test` only (`pubspec.yaml` dev_dependencies: `flutter_test`, `flutter_lints`).
- **What exists:** `test/call_detection_test.dart` (19 tests: `CallEvent.fromMap`, `PhoneContact.normalizePhoneNumber`, `PhoneContact.numbersMatch`, `CallEntry` `toMap/fromMap/copyWith`) and `test/ai_response_parser_test.dart` (6 tests: fences, empty reminder, `HH:MM:SS`, malformed date, non-JSON). All pure-Dart, fast, behaviour-oriented, no mocks. Quality is fine; scope is tiny.
- **What is not covered:** every repository (SQL, cascades, `pendingTasksCount`), every service with I/O (`AiService`, `NotificationService`, `CallMatchingService`, `ContactMergeService`, `SettingsService`), every screen, the Kotlin service/plugin, the overlay engine, migrations (none exist yet).
- **Quality issues:** no CI, so tests are only run by hand; the previous default widget test asserted a counter app and always failed (removed this session); no fixtures/factories; `AiService` uses static `http.post`, `DatabaseHelper` is a hard singleton — both need small seams (T-011).

## 7.3.2 Target test strategy

| Layer | Tool (already in repo unless noted) | Share of effort | Notes |
|---|---|---|---|
| Unit — models, parsers, utils, migration transforms | `flutter_test` | 20 % | Keep pure and fast. |
| Repository/integration — SQL against in-memory SQLite | `sqflite_common_ffi` (new dev dep) with the **real** `DatabaseHelper` schema and migrations | 35 % | This is where data-integrity findings (F-001, F-011…F-014) are locked down. |
| Service — HTTP and platform boundaries | `http/testing.dart` `MockClient` (ships with `http`), hand-written fakes for `PhoneContactService`, `CallDetectionService`, `FlutterLocalNotificationsPlugin` behind thin interfaces | 20 % | No mocking library needed; fakes live in `test/helpers/fakes.dart`. |
| Widget — screens and flows | `flutter_test` `WidgetTester` with ffi DB and fakes injected via constructor params/`InheritedWidget`-free static setters | 20 % | Cover the note→AI→save flow, tasks, contact form, unassigned inbox, reminder sheet. |
| Native — Kotlin | JUnit + Robolectric for `CallEventQueue`; instrumented test optional | 5 % | Keep minimal; device checklist covers the rest. |
| Device/e2e — manual checklist | `docs/system-review/device-checklist.md` | — | Overlay, notifications, permissions, boot restart, release build. `integration_test` package can be added later for smoke tests on a connected device (not in CI). |

Contract tests: the only external contract is the OpenAI-compatible chat completions response; `AiService` tests pin the request body shape (model, `response_format`, `reasoning_effort`) and parse fixture responses recorded from Groq.

## 7.3.3 Coverage gaps to close first (ranked by risk)

1. AI review save/re-review merge (F-001) — TC-013…TC-017.
2. Note persistence without AI (F-003) — TC-008…TC-012.
3. Startup resilience (F-002) — TC-004…TC-007.
4. Reminder scheduling rules and ids (F-004, F-014) — TC-018…TC-023.
5. Repository baseline: cascades, counts, filters (regression net for everything after) — TC-041…TC-047.
6. Migration v1→v2→v3 on a real-shaped fixture (F-011, F-012) — TC-055…TC-065.
7. Native event queue and dedupe (F-007, F-024) — TC-070…TC-076.
8. Call matching → unassigned inbox (F-021) — TC-090…TC-096.

## 7.3.4 Test case specifications

Format: `TC-0XX | Type | Target | Given … When … Then … | Covers`

### Baseline and M0

| ID | Type | Target | Given / When / Then | Covers |
|---|---|---|---|---|
| TC-001 | e2e (manual) | Build pipeline | Given the working tree, when `flutter analyze && flutter test && flutter build apk --debug` run on Windows, then all succeed with 0 issues | T-001, F-009 |
| TC-002 | e2e (manual) | Simulate Call → overlay | Given overlay permission granted and a contact with `0911234567`, when Simulate Call (incoming, `+251911234567`, 20 s) runs, then the overlay shows the contact name while ringing, a text field while active, "Call ended" after | T-001, F-009 |
| TC-003 | e2e (manual) | Overlay → AI Review handoff | Given a note typed in the overlay and "Save & Process" tapped, when the app is reopened, then AI Review opens with that note for that contact | T-001 |
| TC-004 | unit | `NotificationService.init` | Given `FlutterTimezone` returns `"Not/AZone"`, when `init()` runs, then no exception and `tz.local == tz.UTC` | T-002, F-002 |
| TC-005 | widget | `main._initialise` | Given `SeedData.seedIfNeeded` throws, when the app starts, then `StartupErrorScreen` is shown with the error text | T-002, F-002 |
| TC-006 | widget | `StartupErrorScreen` | Given the error screen, when "Reset local data" is confirmed twice, then the DB file is deleted and `SmartBrokerApp` is built | T-002 |
| TC-007 | widget | `SmartBrokerApp` | Given an empty ffi DB, when the app is pumped, then `MainShell` renders Home with empty states | T-002 |
| TC-008 | widget | `AddNoteScreen` Save | Given no AI key, when text is entered and "Save" tapped, then a note row exists with `aiSummary == ''` and the screen pops | T-003, F-003 |
| TC-009 | widget | `AddNoteScreen` Save & AI Review | Given a key and `MockClient` 200, when tapped, then the note is inserted **before** the HTTP call (assert row exists inside the mock handler) and AI Review opens with `noteId` | T-003 |
| TC-010 | widget | `AiReviewScreen` error state | Given `MockClient` throws, when "Keep note without AI" is tapped, then the note remains with empty summary and no todos were created | T-003, F-003 |
| TC-011 | unit | `NoteRepository.saveNote` | Given an existing note id, when called with new text, then the row is updated (no new row) and `contacts.lastInteraction` ≥ now−1s | T-003 |
| TC-012 | widget | `ContactDetailScreen` notes list | Given a note with empty summary, when rendered, then the raw text preview and an "Unprocessed" chip are shown | T-003 |
| TC-013 | integration | `NoteSaveService.applyReview` | Given a note with todos A(completed) and B(open), when the review returns [C], then A remains completed, B is deleted, C is inserted | T-004, F-001 |
| TC-014 | integration | `NoteSaveService.applyReview` | Given todos B(open) and review returns ["b" (case/space variant)], when applied, then B is kept (same id) and nothing inserted | T-004 |
| TC-015 | integration | `NoteSaveService.applyReview` | Given the reminder insert is forced to throw (fake repo), when applied, then the note's todos are unchanged (rollback) | T-004, F-001 |
| TC-016 | integration | `NoteSaveService.applyReview` | Given an existing reminder for the note and switch off, when applied, then the reminder is deleted and `cancelReminder` was called with its id | T-004 |
| TC-017 | widget | `AiReviewScreen` confirm dialog | Given open todo B will be deleted, when Save is tapped, then the dialog lists "B" before proceeding | T-004 |
| TC-018 | unit | `nextFullHour` | Given 14:20, when called, then 15:00 same day; given 23:30 then 00:00 next day | T-005, F-004 |
| TC-019 | widget | `_AddReminderSheet` | Given now = 14:20 and today selected, when opened, then time shows 15:00 | T-005, F-004 |
| TC-020 | widget | `_AddReminderSheet` | Given a time 5 min in the past, when Save is tapped, then the "time has passed" dialog appears; "change time" returns to the sheet without saving | T-005, F-004 |
| TC-021 | unit | `stableId` | Given `'abc'`, when hashed twice (and across a second `flutter test` run), then equal, ≥ 0, < 2³¹ | T-005, F-014 |
| TC-022 | unit | `NotificationService.rescheduleAll` (fake plugin) | Given 2 upcoming + 1 past reminder and one shown post-call notification, when run, then `cancel` called for the 3 reminder ids only, `cancelAll` never, 2 `zonedSchedule` calls | T-005, F-014 |
| TC-023 | unit | `scheduleReminder` return | Given a past reminder, when scheduled, then returns false and the caller shows the "no notification" snackbar (widget assertion in reminder detail) | T-005 |
| TC-024 | widget | `AiConsentDialog` | Given consent not accepted, when AI Review starts, then the dialog is shown and `MockClient` received 0 requests | T-006, F-005 |
| TC-025 | widget | `AiConsentDialog` | Given "I understand" tapped, when AI Review starts again, then no dialog and 1 request | T-006 |
| TC-026 | unit | `SettingsService.aiConsent` | Given provider change, when `setAiProvider` runs, then `ai_consent_accepted` resets to false | T-006 |
| TC-027 | unit | `_mask` | Given `+251911234567`, when masked, then `+2519****567`; log lines never contain `content` (grep on captured `AppLog`) | T-006, F-005 |
| TC-028 | e2e (manual) | Release build | Given `key.properties`, when `flutter build apk --release`, then `apksigner verify --print-certs` shows the release cert | T-007, F-006 |
| TC-029 | e2e (manual) | Launcher label | When installed, then "SmartBroker" label and icon | T-007 |
| TC-030 | e2e (manual) | Backup rules | When `adb shell bmgr backupnow`, then DB included, secure-storage prefs excluded (inspect rules XML + logcat) | T-007 |
| TC-031 | unit | `SeedData.seedIfNeeded` | Given `kDebugMode == false` (test via injected flag), when run on empty DB, then 0 contacts | T-008, F-010 |
| TC-032 | unit | `SeedData.loadDemoData` | Given empty DB, when run, then 8 contacts and reminders exist | T-008 |
| TC-033 | unit | `mock_contacts.dart` | When inspected, then no email domain other than `example.com` and no name matching the developer's | T-008, F-010 |
| TC-034 | unit | `pubspec.yaml` fonts | When parsed, then family `Inter` with 4 weights declared and files exist | T-009, F-015 |
| TC-035 | e2e (manual) | Offline cold start | Given airplane mode, when launched, then Inter renders (screenshot compare) | T-009 |
| TC-036 | widget | `NotesListScreen._performSearch` | Given a slow fake repo, when the screen is popped mid-search, then no exception | T-010, F-022 |
| TC-037 | widget | `ReminderDetailScreen` | Given edit mode, when popped during `_saveChanges`, then no double-dispose | T-010, F-022 |
| TC-038 | unit | `StringExtension.capitalize` | Given `''`, then `''`; given `'abc'`, then `'Abc'` | T-010, F-033 |
| TC-039 | widget | `_AddReminderSheet` | When closed, then its controller is disposed (assert via a spy subclass) | T-010, F-027 |
| TC-040 | unit | `TaskFilter` mapping | Given each enum value, when mapped, then the repository receives the expected filter | T-010 |
| TC-041 | integration | `ContactRepository` cascade | Given a contact with 1 note, 1 todo, 1 reminder, 1 call, when deleted, then all child rows are gone | T-011 |
| TC-042 | integration | `NoteRepository.delete` | Given a note with a todo and reminder, when deleted, then their `noteId` is NULL and rows remain | T-011 |
| TC-043 | integration | `TodoRepository` counts | Given 2 open + 1 completed todos, when `toggleCompleted` on one open, then `pendingTasksCount == 1` | T-011, F-013 |
| TC-044 | integration | `ReminderRepository.getUpcoming/getOpen/getOverdue` | Given past-open, future-open, past-completed, when queried, then upcoming=[future], open=[past, future], overdue=[past] | T-011 |
| TC-045 | unit | `AiService.analyzeNote` | Given `MockClient` 200 with fenced JSON, then `AiResult` parsed; body has `response_format.json_schema.strict == true` and `reasoning_effort == 'low'` for Groq | T-011 |
| TC-046 | unit | `AiService.analyzeNote` | Given first 400 then 200, then second request has no `response_format`; given 401 → `invalidKey`; 429 → `rateLimited`; timeout → `unknown` | T-011 |
| TC-047 | unit | `ContactMergeService.getUnifiedContacts` | Given phonebook `0911 23 45 67` twice and CRM `+251911234567`, then one merged entry with `isSmartBrokerContact && isPhoneContact` | T-011 |
| TC-048 | e2e (CI) | `ci.yml` | Given a PR with a failing test, when CI runs, then the check is red | T-012 |
| TC-049 | e2e (CI) | `ci.yml` | Given main, when CI runs, then format/analyze/test/build/coverage-gate all green in < 12 min | T-012 |
| TC-050 | e2e (CI) | `coverage_gate.sh` | Given lcov at 35 % and threshold 40, then exit 1 | T-012 |
| TC-051 | unit | `CallMatchingService._handleStateChange` (fake overlay) | Given mode `knownOnly` and unknown number ringing, then `showOverlay` not called | T-013, F-021 |
| TC-052 | unit | same | Given known number, then `showOverlay` called and state has `contactName` | T-013 |
| TC-053 | unit | same | Given mode `all` and unknown number, then overlay shown with the number as title | T-013 |
| TC-054 | unit | post-call prompt gate | Given unknown caller and 60 s duration, then `showPostCallPrompt` not called | T-013 |

### M1

| ID | Type | Target | Given / When / Then | Covers |
|---|---|---|---|---|
| TC-055 | integration | `MigrationV2` | Given a DB created with the v1 DDL and 3 contacts/2 todos/2 reminders/3 calls, when upgraded, then all rows survive, `phoneKey` backfilled, `notificationId == stableId(id)` | T-014, F-011 |
| TC-056 | integration | `MigrationV2` | Given two calls with the same (contactId, timestamp), when upgraded, then one remains and the unique index exists | T-014, F-024 |
| TC-057 | integration | `DatabaseHelper` fresh | Given no DB, when opened, then `PRAGMA user_version == 3` and all indexes listed | T-014 |
| TC-058 | integration | `UnassignedCallRepository` | Insert/list by status/markAssigned round-trip | T-014 |
| TC-059 | integration | `TodoRepository` | Given `dueAt` set, when `fromMap(toMap)`, then preserved; NULL preserved | T-014 |
| TC-060 | integration | migration idempotence | Given a v2 DB, when opened again, then no migration runs (`_onUpgrade` not invoked) | T-014 |
| TC-061 | integration | `ContactRepository.insert` | Given an existing contact `+251911234567`, when inserting `0911234567`, then the existing id is returned and row count unchanged | T-015, F-012 |
| TC-062 | integration | `ContactRepository.getAll` | Given 2 open todos, when loaded, then `pendingTasksCount == 2` without any stored column write | T-015, F-013 |
| TC-063 | integration | `ContactRepository.update` | Given a stale object with `pendingTasksCount = 99`, when updated, then live count is still correct | T-015, F-013 |
| TC-064 | integration | `MigrationV3` | Given duplicate contacts A (older) and B (newer, same key) each with a note, when upgraded, then one contact with 2 notes and the unique index exists | T-015, F-012 |
| TC-065 | widget | `PhoneContactDetailScreen` | Given the number already exists in CRM, when "Add to SmartBroker" tapped, then it opens the existing contact | T-015 |
| TC-066 | unit | `DataChangeNotifier` | When `notify(todos)` twice within 100 ms, then listeners fire once with version incremented | T-016 |
| TC-067 | widget | `HomeScreen` | Given Home mounted, when a todo is completed through `TodoRepository`, then the pending count pill updates without navigation | T-016, F-017 |
| TC-068 | widget | `ContactsScreen` | Given list mounted, when a contact is inserted, then it appears | T-016, F-017 |
| TC-069 | static | `lib/features` | When grepped, then 0 occurrences of `.then((_) => _loadData())` | T-016 |
| TC-070 | unit (JUnit) | `CallEventQueue` | Given 2 enqueued events, when drained, then both returned in order and the store is empty | T-017, F-007 |
| TC-071 | unit (JUnit/Robolectric) | `CallDetectionService.post` | Given `eventSink == null`, when a `call_logged` event is posted, then it is enqueued; a `state` event is not | T-017, F-007 |
| TC-072 | unit | `CallDetectionService.drainQueuedEvents` (Dart, fake channel) | Given the channel returns 2 maps, when `startListening` runs, then `_handleRawEvent` is called twice before subscribing | T-017 |
| TC-073 | integration | `CallMatchingService._logCall` | Given the same event twice, when processed, then one `calls` row (unique index conflict swallowed) | T-017, F-024 |
| TC-074 | e2e (manual) | Force-stop | Given detection on, app force-stopped, a call received, when the app opens, then the call is on the contact | T-017, F-007 |
| TC-075 | e2e (manual) | Reboot | Given detection on, when the phone reboots, then the foreground notification is present within 1 min | T-017, F-007 |
| TC-076 | unit (JUnit) | `fetchLastCallFromLog` retry | Given no row newer than `lastSeen` on first query and one on second, then one event emitted | T-017, F-024 |
| TC-077 | unit | `PhoneContactService.getContacts` cache | Given a fake `FlutterContacts` counter, when called twice within TTL, then 1 underlying call; `force: true` → 2 | T-018, F-016 |
| TC-078 | unit | `ContactMergeService` | When merging, then `requestPermission` is not invoked (fake asserts) | T-018 |
| TC-079 | widget | `ContactsScreen` denied banner | Given permission denied, when rendered, then the "Allow contacts access" banner shows | T-018 |
| TC-080 | widget | `ContactsScreen` refresh | When pull-to-refresh, then `getContacts(force: true)` called | T-018 |
| TC-081 | widget | `ContactFormScreen` create | Given valid name+phone, when saved, then a contact exists with normalised phone | T-019, F-019 |
| TC-082 | widget | `ContactFormScreen` validation | Given empty name, when saved, then error shown and no insert | T-019 |
| TC-083 | widget | `ContactFormScreen` duplicate | Given an existing number, when saved, then "Open existing" offered | T-019 |
| TC-084 | widget | `ContactDetailScreen` ⋯ Edit | When Edit chosen and name changed, then header updates and notes remain | T-019 |
| TC-085 | integration | delete contact | Given a contact with a future reminder, when deleted, then `cancelReminder(id)` called and no rows remain | T-019 |
| TC-086 | widget | delete confirm | When Delete chosen, then the dialog shows counts "2 notes, 1 task, 1 reminder, 3 calls" | T-019 |
| TC-087 | widget | Home → Notes list | When "See all" tapped, then `NotesListScreen` is pushed | T-020, F-019 |
| TC-088 | widget | Home banner | Given 2 notes with empty summary, then "2 notes waiting for AI" shown | T-020 |
| TC-089 | static | `lib/` | When grepped, then 0 `onTap: () {}` / `onPressed: () {}` | T-020, F-019 |
| TC-090 | integration | `_logCall` unknown | Given unknown number, when processed, then 0 new contacts and 1 `unassigned_calls` row with status `new` | T-021, F-021 |
| TC-091 | integration | assign | Given an unassigned row and contact X, when assigned, then a `calls` row for X exists, the unassigned row is gone, `lastInteraction` updated | T-021 |
| TC-092 | integration | assign + pending review | Given `pending_ai_review` without contact, when assigned, then it carries X's id | T-021 |
| TC-093 | widget | `UnassignedCallsScreen` grouping | Given 3 calls from one number, then one group with "3 calls" | T-021 |
| TC-094 | widget | Create contact from inbox | When tapped, then `ContactFormScreen` opens with the number prefilled and on save the call is assigned | T-021 |
| TC-095 | widget | Dismiss | When dismissed, then status `dismissed` and hidden; a new call from the same number reappears grouped | T-021 |
| TC-096 | unit | notification payload | Given unknown caller ≥ min duration, then `show` called with payload `/unassigned?id=` | T-021 |
| TC-097 | unit | `AiResponseParser` | Given `actionItems: [{"title":"Send offer","dueDate":"2026-10-02"}]`, then item has `dueAt == 2026-10-02` | T-022, F-020 |
| TC-098 | unit | `AiResponseParser` legacy | Given `actionItems: ["Send offer"]`, then item with null `dueAt` | T-022 |
| TC-099 | unit | `_noteSchema` | When serialised, then `actionItems.items` is an object schema with `required: [title, dueDate]`, `additionalProperties: false` | T-022 |
| TC-100 | integration | `TodoRepository.getAll(overdue)` | Given due yesterday (open), due tomorrow, due yesterday (completed), then only the first | T-022, F-020 |
| TC-101 | widget | `TodoTile` | Given overdue task, then red date chip | T-022 |
| TC-102 | widget | add-task sheet | When a date is picked, then the saved todo has `dueAt` at 09:00 that day | T-022 |
| TC-103 | static | repo tree | When listed, then `web/ linux/ macos/ windows/` absent | T-023, F-030 |
| TC-104 | e2e (CI) | build | APK build still green after removal | T-023 |
| TC-105 | unit | `AppLog` | Given 600 entries, when logged, then buffer holds the last 500 | T-024 |
| TC-106 | unit | `AppLog` release | Given `kDebugMode == false`, when logged, then no console output (capture `Zone.print`) | T-024, F-005 |
| TC-107 | widget | `LogViewerScreen` | Given an uncaught error thrown in a widget, then it appears in the viewer | T-024, F-032 |
| TC-108 | static | `lib/` | When grepped, then `print(`/`debugPrint(` only in `app_log.dart` | T-024 |

### M2

| ID | Type | Target | Given / When / Then | Covers |
|---|---|---|---|---|
| TC-109 | unit | `QuickActionsService.toE164` | Given `0911 234 567` and default `+251`, then `+251911234567`; given `+251911234567`, unchanged | T-025 |
| TC-110 | unit | URL builders | `whatsapp` → `https://wa.me/251911234567`; `telegram` → `tg://resolve?phone=251911234567`; `sms` → `sms:+251911234567` | T-025 |
| TC-111 | widget | contact header | Given a contact, then four action buttons with semantics labels | T-025 |
| TC-112 | e2e (manual) | device | Each button opens the target app; uninstalling WhatsApp yields a snackbar | T-025 |
| TC-113 | integration | `BackupService.export` | Given seeded DB, when exported, then JSON has `schemaVersion == current`, all 6 collections with correct counts | T-026, N-003 |
| TC-114 | integration | round-trip | Given export → wipe → restore, then row counts and id sets identical; `rescheduleAll` invoked | T-026 |
| TC-115 | integration | invalid file | Given truncated JSON, when restored, then exception, DB unchanged | T-026 |
| TC-116 | integration | newer version | Given `schemaVersion = 99`, then rejected with message | T-026 |
| TC-117 | integration | older version | Given a v2-format file, when restored into v3, then `phoneKey` recomputed and duplicates merged | T-026 |
| TC-118 | widget | restore confirm | When restore chosen, then requires typing `RESTORE` and auto-exports first | T-026 |
| TC-119 | e2e (manual) | share sheet | When export tapped, then the OS share sheet offers the file | T-026 |
| TC-120 | unit | `readCallLog` (fake channel) | Given 3 rows, when imported, then only rows matching CRM numbers inserted | T-027 |
| TC-121 | integration | import twice | Then no duplicates (unique index) | T-027 |
| TC-122 | integration | `lastInteraction` | After import, equals the newest matched call timestamp if later than current | T-027 |
| TC-123 | widget | Settings import | Choosing "90 days" passes `since = now − 90d` | T-027 |
| TC-124 | unit | briefing body (fixed clock) | Given 2 reminders today, 1 due task, 3 unassigned, then "2 reminders · 1 task due · 3 unassigned calls" | T-028 |
| TC-125 | unit | `scheduleDailyBriefing` (fake plugin) | Given 08:00 configured, then `zonedSchedule` with id 1 and `matchDateTimeComponents: time` | T-028 |
| TC-126 | unit | toggle off | Then `cancel(1)` called | T-028 |
| TC-127 | integration | `ContactRepository.touch` | After `TodoRepository.insert`, contact `lastInteraction` ≥ now−1s | T-029, F-025 |
| TC-128 | integration | `getGoneQuiet(7)` | Given contact untouched 8 days with open todo, and one untouched 8 days without todos, then only the first | T-029 |
| TC-129 | widget | Home section | Renders "Gone quiet" rows | T-029 |
| TC-130 | integration | note insert | After `NoteRepository.saveNote`, `lastInteraction` bumped | T-029, F-025 |
| TC-131 | unit | `AiOrchestrator` | Given Groq 429 then OpenRouter 200, then result with `providerUsed == openrouter` | T-030, N-011 |
| TC-132 | unit | `AiOrchestrator` | Given Groq 401, then `invalidKey` surfaces immediately (no fallback for auth errors) | T-030 |
| TC-133 | unit | `AiOrchestrator` | Given all providers 429, then last `rateLimited` surfaces | T-030 |
| TC-134 | widget | chip | Fallback used → chip text mentions the provider | T-030 |
| TC-135 | e2e (manual, spike) | `CallScreeningService` | Given screening role granted, when a call arrives, then the number is received without `READ_CALL_LOG` | T-031, F-008 |
| TC-136 | doc | ADR-0001 | Contains options, decision, consequences, follow-up task IDs | T-031 |
| TC-137 | widget | Home task row | When tapped, then `contactDetail` pushed and the todo is still open | T-032, F-023 |
| TC-138 | widget | `ReminderCard` on contact detail | When tapped, then `reminderDetail` pushed; when circle tapped, then completed and `cancelReminder` called | T-032, F-023 |
| TC-139 | unit | `isSameCalendarDay` | Given 23:30 yesterday vs 00:30 today, then false | T-032, F-026 |
| TC-140 | widget | calendar empty text | Given a non-today selected day, then "No reminders on this day" | T-032, F-026 |
| TC-141 | widget | calendar range | Given today = 2031-01-01, then no assertion and `lastDay` ≥ today | T-032, F-026 |
| TC-142 | widget | contact search | Given `+251 911 234 567`, when searching `0911`, then found | T-032, F-029 |
| TC-143 | integration | `ContactRepository.search('%')` | Then only names containing a literal `%` | T-032, F-029 |
| TC-144 | widget | nav semantics | `find.bySemanticsLabel('Home')` etc. find 4 items | T-032, F-031 |
| TC-145 | unit | `TodoRepository` typed filter | Each filter builds the expected `where` and args | T-032, F-033 |

### M3 / M4

| ID | Type | Target | Given / When / Then | Covers |
|---|---|---|---|---|
| TC-146 | unit | `AiService.transcribe` | Given `MockClient` returning `{text: "hello"}`, when a file is sent, then multipart with `model = whisper-large-v3-turbo` and result "hello" | T-033 |
| TC-147 | widget | record flow | Given fake recorder, when record → stop, then "Transcribing…" then text in editor | T-033 |
| TC-148 | widget | failure | Given transcription throws, then audio kept and Retry shown | T-033 |
| TC-149 | integration | note delete | Deleting a note deletes its `audioPath` file | T-033 |
| TC-150 | e2e (manual) | Amharic/English memo | 3 memos transcribed; accuracy judged acceptable (record in ADR/feasibility note) | T-033 |
| TC-151 | integration | `SearchRepository` | Given contact "Abebe", note "viewing in Bole", task "Send offer", when searching "bole", then the note only | T-034 |
| TC-152 | integration | index maintenance | After editing the note, search reflects new text | T-034 |
| TC-153 | integration | escape | Query `%` returns no wildcard matches | T-034, F-029 |
| TC-154 | integration | perf | 5,000 rows, query < 50 ms (ffi) | T-034 |
| TC-155 | integration | `setStage/getByStage` | Round-trip and filter | T-035 |
| TC-156 | integration | tags unique | Adding the same tag twice yields one row | T-035 |
| TC-157 | widget | stage filter | Contacts filter by "Offer" shows only those | T-035 |
| TC-158 | unit | AI stage suggestion | Unknown stage string ignored | T-035 |
| TC-159 | widget | greeting | Given `user_name = "Bethel"`, then "Bethel"; empty → only greeting line | T-036, F-028 |
| TC-160 | widget | dark theme | `ThemeMode.dark` renders Home, Contacts, Settings without overflow; key text contrast ≥ 4.5:1 (computed) | T-036 |
| TC-161 | unit | `SettingsService.themeMode` | Round-trip | T-036 |
| TC-162 | e2e (CI) | `flutter gen-l10n` | Succeeds; no untranslated-messages file entries | T-037 |
| TC-163 | widget | locale `am` | Home title strings equal `app_am.arb` values | T-037 |
| TC-164 | static | string literals | Lint script finds 0 hardcoded user-visible strings in `lib/features` (allowlist for dev tools) | T-037 |
| TC-165 | unit (spike) | sync merge | Given local and remote rows with different `updatedAt`, then newer wins | T-038 |
| TC-166 | doc | ADR-0002 | Reviewed and accepted | T-038 |
| TC-167 | integration (spike) | encrypted migration | Plain DB → export → encrypted import round-trips | T-039, F-034 |
| TC-168 | doc | ADR-0003 | Decision recorded | T-039 |

## 7.3.5 Test infrastructure needs

- **Database:** `sqflite_common_ffi` (dev dependency, T-011); `test/helpers/test_db.dart` sets `databaseFactory = databaseFactoryFfi` and resets the singleton; migration fixtures under `test/fixtures/db/v1_ddl.sql` (verbatim copy of today's `_onCreate`) so upgrades are always tested from the real starting point.
- **Fixtures/factories:** `test/helpers/fixtures.dart` with `aContact({...})`, `aNote()`, `aTodo()`, `aReminder()`, `aCall()`, `anUnassignedCall()` returning models with sensible defaults; `seedScenario(db, ...)` helpers for common shapes (contact with mixed todos, duplicate numbers).
- **External services:** `http.testing.MockClient` with recorded Groq responses in `test/fixtures/ai/*.json`; fakes for `PhoneContactService`, `CallDetectionService` (channel replaced by a `StreamController`), `FlutterLocalNotificationsPlugin` (wrap behind `NotificationGateway` interface in T-005 so tests count `zonedSchedule/cancel` calls), `FlutterOverlayWindow` (static → wrap in `OverlayGateway` in T-013).
- **Clock:** inject `DateTime Function() now` into services that reason about time (`ReminderRepository`, briefing, nudges) — default `DateTime.now`.
- **Widget tests:** pump screens with real repositories over ffi DB; navigation asserted with `NavigatorObserver` spy.
- **Native:** `androidTest`-free JUnit for `CallEventQueue` (pure Kotlin with an injected `SharedPreferences`-like map); Robolectric optional for the service.
- **Device checklist:** `docs/system-review/device-checklist.md` — overlay, permissions, notifications, force-stop, reboot, release build; run before each release.
- **CI parallelisation:** not needed; suite target < 60 s. Cache pub and Gradle.

## 7.3.6 Non-functional testing

- **Performance:** ffi benchmark tests (guarded with `@Tags(['perf'])`) — `ContactRepository.getAll` with 2,000 contacts/10,000 todos < 100 ms; `ContactMergeService` with 5,000 phonebook entries < 300 ms; global search (TC-154). Device: cold start to first frame < 2 s on the Samsung test phone (manual, `flutter run --profile` timeline).
- **Security:** authorisation matrix is trivial (single local user) — instead: (1) log-leak test TC-027/TC-106; (2) fuzz `AiResponseParser` with 200 random/malformed strings (must never throw anything but `FormatException`); (3) SQL wildcard/escape tests TC-143/TC-153; (4) backup file tamper test TC-115; (5) manual check that release APK has minification and no debug flags (`aapt dump badging`).
- **Accessibility:** widget tests with `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline` on Home, Contacts, Settings (Flutter's built-in a11y guidelines); semantics labels TC-144; large-font (`textScaleFactor 1.6`) overflow test on Home and Contact detail.
- **Migration tests:** every `MigrationVn` has a fixture-based upgrade test (TC-055, TC-064) plus an "open fresh" test (TC-057) and idempotence (TC-060); backup restore across versions TC-117.
- **Reliability:** force-stop and reboot manual cases TC-074/TC-075; notification persistence TC-022.

## 7.3.7 CI quality gates (must pass before merge)

Proposed `.github/workflows/ci.yml` (T-012):

```yaml
name: ci
on: [push, pull_request]
jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { channel: stable, flutter-version: 3.38.x, cache: true }
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed lib test
      - run: flutter analyze --fatal-infos
      - run: flutter test --coverage
      - run: bash tool/coverage_gate.sh 40      # raise to 60 at M2, 70 at M3
      - run: bash tool/no_dead_handlers.sh      # greps for 'onTap: () {}' / 'onPressed: () {}' / stray print(
      - run: flutter build apk --debug
      - uses: actions/upload-artifact@v4
        with: { name: app-debug.apk, path: build/app/outputs/flutter-apk/app-debug.apk }
```

Gates: format ✓ · analyze (fatal infos) ✓ · tests ✓ · coverage ≥ threshold ✓ · no dead handlers / stray prints ✓ · debug APK builds ✓. Dependency audit: run `flutter pub outdated` weekly via a scheduled workflow that opens an issue (no Dart-native vulnerability DB exists; rely on pub.dev advisories surfaced by `pub get` warnings). Branch protection on `main` requires the `flutter` job.
