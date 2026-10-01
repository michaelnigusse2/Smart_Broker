# 03 — Recommendations

Section 0 (product goals) was not supplied with the brief. The goals below are **[Assumed]** from the project README and the product owner's stated intent during this session; every recommendation is scored against them.

**Assumed goals (G-1…G-5)**
- **G-1** Never lose a client interaction: every call and every note ends up on the right contact, with follow-ups that actually fire.
- **G-2** Zero running cost: no backend, free AI tiers, side-loaded or Play-distributed Android app.
- **G-3** Single broker, single phone today; keep the door open to backup, multi-device and a small team later.
- **G-4** Ethiopian context: local (`09…`) and international (`+251…`) numbers, Telegram/WhatsApp-heavy communication, intermittent connectivity, Amharic users eventually.
- **G-5** Solo developer working part-time with an AI assistant; changes must be small, verifiable on a real device, and not require new infrastructure.

---

## 6.1 Improvements to the existing system

| ID | What | Why (findings) | Expected benefit | Effort | Risk |
|---|---|---|---|---|---|
| **I-001** | Startup guard: `runZonedGuarded`, per-step try/catch in `main()`, tz fallback to UTC, "startup failed" screen with Reset option | F-002 | No more blank-screen launches; diagnosable failures | S | Low |
| **I-002** | Notes-first save: persist raw note before AI; AI as retryable enrichment; transactional, non-destructive re-review that keeps completed tasks | F-001, F-003 | Zero note loss offline; completed-task history preserved | M | Medium — touches the core flow; needs widget tests |
| **I-003** | Release readiness: `key.properties` signing, app name/icon, explicit backup rules, `versionCode` bump script, `enableOnBackInvokedCallback` | F-006 | Installable, updatable, branded build | S | Low (must never lose the keystore) |
| **I-004** | Privacy & logging hygiene: AI-processing consent notice, `AppLog` gated by `kDebugMode`, no PII in logs, global error handlers with local log buffer | F-005, F-032 | Informed consent; no leakage via logcat; crash visibility without third-party SDK | S+M | Low |
| **I-005** | Native call-event queue + boot restart: persist `call_logged` events in Kotlin when no Dart sink; drain on `startListening()`; `BOOT_COMPLETED` receiver restarts service if enabled; robust call-log query (`DATE > lastSeen`, retry) | F-007, F-024 | Calls are captured even when the app was killed; no duplicate/missed logs | M | Medium — native code, Samsung battery quirks |
| **I-006** | Reminder correctness: next-full-hour default, past-time guard, stable stored notification id, remove `cancelAll()` | F-004, F-014 | Reminders fire as the user expects; prompts survive app launch | S | Low |
| **I-007** | Debug-only seeding + "Load demo data" developer action; fictional mock identities | F-010 | Clean first run for real users; PII out of repo | S | Low |
| **I-008** | Schema v2 via versioned migrations: indexes, `phoneKey` unique, `dueAt` on todos, `notificationId` on reminders, `unassigned_calls` table; computed task counts | F-011, F-012, F-013 (+ enables N-001, N-002) | Safe evolution of the DB; no duplicates; correct counts | M | Medium — first migration on real data; needs migration tests |
| **I-009** | Bundle Inter font | F-015 | Offline-consistent UI; one fewer external call | S | Low |
| **I-010** | Phonebook cache (in-memory, 5-min TTL, explicit refresh) and explicit permission onboarding | F-016 | Instant Contacts tab; no surprise permission dialogs | M | Low |
| **I-011** | `DataChangeNotifier`: repositories call `notify()` after writes; screens use `ListenableBuilder`/listener to reload; tabs refresh on change instead of on pop | F-017 | Fresh data everywhere with less code than the current `.then(_loadData)` pattern; no new dependency | L | Medium — touches every screen; do incrementally |
| **I-012** | Test harness + CI: `sqflite_common_ffi` repo tests, `MockClient` AI tests, widget tests for note→AI→save and tasks; GitHub Actions running format/analyze/test/build | F-018, F-009 | Regressions caught before device time | M | Low |
| **I-013** | Contact CRUD, notes-list entry point, settings clean-up (implement Reset data; remove Theme/Clear-cache/Debug placeholders until real) | F-019 | Complete basic CRM hygiene; no dead buttons | M | Low |
| **I-014** | Polish batch: `mounted` guards, controller disposal, Home tap semantics, reminder cards actionable, calendar range/date-format fixes, normalised search, semantics on icon controls, enum filters, `capitalize` guard, Gradle heap 4G | F-022, F-023, F-025, F-026, F-027, F-029, F-031, F-033 | Fewer crashes and paper-cuts | M (sum of S items) | Low |
| **I-015** | Delete `web/`, `linux/`, `macos/`, `windows/` scaffolding (keep `ios/` dormant) | F-030 | Clear target scope; no accidental wrong-platform runs | S | Low (recoverable via `flutter create .`) |
| **I-016** | Play-compatibility spike (ADR): `CallScreeningService`/`ROLE_CALL_SCREENING` vs default-dialer vs side-load distribution | F-008 | Informed decision before investing further in call features | L (time-boxed 2 days) | Low |
| **I-017** | Overlay/prompt gating: overlay only for known contacts (setting: Known / All / Off); post-call prompt only for known or "ask to assign" for unknown | F-021 | No interruptions on spam/personal calls | S | Low |
| **I-018** | Profile name setting, dark theme, l10n scaffold | F-028 | Personalised, ready for Amharic | M | Low |
| **I-019** | Encryption at rest evaluation (`sqflite_sqlcipher`) and optional biometric app lock | F-034 | Protection of client data on lost/rooted devices | M | Medium — migration of existing DB; new dependency; only when distribution widens |

---

## 6.2 New feature suggestions

Scores: Impact 1–5 · Effort S/M/L/XL · Confidence 1–5 (that it will deliver the impact) · Fit 1–5 (with G-1…G-5).

### N-001 · Unassigned calls inbox
- **User problem / who:** Calls from numbers not in the CRM currently become junk contacts (F-021). The broker wants new leads captured without polluting the list.
- **Description / stories:** As a broker I want unknown calls to land in an "Unassigned" inbox so that I can turn a real lead into a contact in one tap and dismiss the rest. As a broker I want to assign an unassigned call to an existing contact so that a client calling from a new number is merged correctly.
- **Fit with architecture:** New table `unassigned_calls(id, phoneNumber, phoneKey, type, duration, timestamp, note, status)` via migration (I-008); `UnassignedCallRepository`; `CallMatchingService._logCall` inserts here instead of creating a contact; new `features/calls/screens/unassigned_calls_screen.dart` reached from Home stat pill + Contacts app-bar badge; "Create contact" reuses the contact form (I-013); "Assign" moves the row into `calls` for the chosen contact and re-attaches any `pending_ai_review`/draft.
- **Scores:** Impact 4 · Effort M · Confidence 5 · Fit 5
- **Dependencies:** T-014 (migrations), T-019 (contact form)
- **Recommendation:** **Do now** (M1) — explicitly requested; removes a data-integrity problem.

### N-002 · Task due dates and real "overdue"
- **User problem:** Tasks carry no date, so "overdue" is fictional (F-020) and reminders are the only dated object.
- **Stories:** As a broker I want a task to have an optional due date so that "Overdue" means what it says and Home shows what is due today. As a broker I want AI Review to propose due dates for action items when the note mentions them.
- **Fit:** `todos.dueAt INTEGER NULL` (I-008); `TodoItem.dueAt`; AI schema gains `actionItems: [{title, dueDate?}]` (keep backward compatibility by accepting strings); `TodoRepository.getAll(filter: overdue)` → `dueAt < now`; date chip in `TodoTile`; Home "Due today".
- **Scores:** Impact 4 · Effort M · Confidence 4 · Fit 5
- **Dependencies:** T-014
- **Recommendation:** **Do now** (M1).

### N-003 · Backup, export and restore
- **User problem:** The phone is the only copy of the data (no backend, G-3). A lost phone = lost CRM.
- **Stories:** As a broker I want to export everything to a file I can keep in Drive/Telegram so that I can recover after losing my phone. As a broker I want to restore that file on a new phone.
- **Fit:** `BackupService` serialises all five tables to a versioned JSON (`schemaVersion`, `exportedAt`), writes to app documents via `path_provider` (already transitive; make it direct) and hands it to the OS share sheet via `share_plus`; import validates version, wipes and re-inserts inside a transaction, then `rescheduleAll()`. Settings → "Backup & restore".
- **Scores:** Impact 5 · Effort M · Confidence 5 · Fit 5
- **Dependencies:** T-014 (versioned schema) · new deps `share_plus`, `file_picker` (see compatibility note in `04-implementation-plan.md`).
- **Recommendation:** **Do now** (M2, first item) — cheapest insurance against the biggest risk.

### N-004 · Quick actions: call / WhatsApp / Telegram / SMS from a contact
- **User problem:** The broker reads a note then switches apps to reach the client (G-4).
- **Stories:** As a broker I want one-tap Call / WhatsApp / Telegram / SMS on the contact header so that follow-ups happen from the CRM.
- **Fit:** `url_launcher` (`tel:`, `sms:`, `https://wa.me/<E.164>`, `tg://resolve?phone=`), buttons in `contact_detail_screen.dart` header; outgoing call triggers existing call detection.
- **Scores:** Impact 4 · Effort S · Confidence 5 · Fit 5
- **Dependencies:** none (needs `<queries>` entries in the manifest for Android 11+)
- **Recommendation:** **Do now** (M2) — quick win.

### N-005 · Voice notes with transcription
- **User problem:** Typing after a call is slow; brokers are often driving/walking.
- **Stories:** As a broker I want to record a voice memo after a call and have it transcribed and processed like a typed note.
- **Fit:** Record with the `record` package to m4a; upload to Groq `POST /openai/v1/audio/transcriptions` (`whisper-large-v3-turbo`, free tier; same key/provider abstraction — add `transcriptionsUrl` to `AiProvider`); transcript flows into `AddNoteScreen` → AI Review. Store audio path on the note (`notes.audioPath`, migration).
- **Scores:** Impact 5 · Effort L · Confidence 3 (free-tier audio limits and Amharic accuracy unverified) · Fit 4
- **Dependencies:** T-003 (notes-first), T-014, T-030 (provider abstraction)
- **Recommendation:** **Do next** (M3) after a 1-day feasibility check of Whisper quality on Amharic/English mix.

### N-006 · Daily briefing notification
- **User problem:** Follow-ups are only visible if the app is opened.
- **Stories:** As a broker I want an 8:00 notification listing today's reminders, due tasks and unassigned calls so that I start the day knowing who to call.
- **Fit:** One repeating `zonedSchedule` (`matchDateTimeComponents: time`) whose body is rebuilt on each app launch/`rescheduleAll`; tap opens Home. No background execution needed.
- **Scores:** Impact 3 · Effort S · Confidence 4 · Fit 5
- **Dependencies:** N-002 for "due tasks"
- **Recommendation:** **Do now** (M2) — quick win.

### N-007 · Call-log history import
- **User problem:** Only calls after enabling detection are logged; past interactions with known contacts are invisible.
- **Stories:** As a broker I want to import my recent call history for my CRM contacts so that "last interaction" is accurate from day one.
- **Fit:** New MethodChannel method `readCallLog(sinceMs)` in `CallDetectionPlugin` returning rows; Dart matches with `PhoneContact.numbersMatch`, inserts `CallEntry` with dedupe on (contactId, timestamp), updates `lastInteraction`. Settings → "Import call history".
- **Scores:** Impact 3 · Effort M · Confidence 4 · Fit 4
- **Dependencies:** T-014 (unique index on calls), T-017 (native refactor)
- **Recommendation:** **Do next** (M2, late) — depends on the F-008 decision.

### N-008 · Follow-up nudges ("gone quiet")
- **User problem:** Leads decay silently.
- **Stories:** As a broker I want Home to show contacts with open tasks or deals I haven't touched in N days so that nothing slips.
- **Fit:** Query on `lastInteraction` + open todos; section on Home; requires `lastInteraction` to be bumped on notes/tasks (F-025).
- **Scores:** Impact 3 · Effort S · Confidence 4 · Fit 5
- **Recommendation:** **Do now** (M2) — quick win, mostly SQL.

### N-009 · Global search
- **User problem:** Search exists only inside Contacts and the (unreachable) Notes list.
- **Stories:** As a broker I want one search box that finds contacts, notes and tasks.
- **Fit:** `SearchRepository` with three `LIKE` queries (escaped) or an FTS5 virtual table (sqflite on Android supports FTS5); search screen from Home app bar.
- **Scores:** Impact 3 · Effort M · Confidence 4 · Fit 4
- **Recommendation:** **Do next** (M3).

### N-010 · Deal pipeline and contact tags
- **User problem:** A broker's contacts are buyers, sellers, landlords, tenants at different stages; the app treats them all alike.
- **Stories:** As a broker I want to tag contacts (Buyer/Seller/Landlord/…) and set a stage (Lead → Viewing → Offer → Closed) so that I can filter my pipeline.
- **Fit:** `contacts.stage TEXT`, `contact_tags(contactId, tag)` tables; chips on contact detail; pipeline filter on Contacts; Home stat.
- **Scores:** Impact 4 · Effort L · Confidence 3 (needs product validation of stages) · Fit 4
- **Recommendation:** **Later** (M3) — validate with real usage first.

### N-011 · AI provider fallback chain
- **User problem:** Free tiers rate-limit or rotate models (this already broke NVIDIA and Groq-Llama).
- **Stories:** As a broker I want the app to try my second provider automatically when the first is rate-limited so that AI Review just works.
- **Fit:** `AiService.fromSettings()` returns an ordered list of configured providers; `analyzeNote` tries the next on 429/5xx/timeout; Settings shows the order.
- **Scores:** Impact 3 · Effort S · Confidence 5 · Fit 5
- **Recommendation:** **Do now** (M2).

### N-012 · Amharic localisation
- **Stories:** As an Amharic-speaking broker I want the UI in Amharic.
- **Fit:** `flutter_localizations` + `intl` (already 0.20.2, the version Flutter 3.38 pins) + `l10n.yaml`; `app_en.arb`, `app_am.arb`; AI prompts stay English but summaries can be requested in the UI language.
- **Scores:** Impact 3 · Effort L · Confidence 4 · Fit 4
- **Dependencies:** I-018 scaffold
- **Recommendation:** **Later** (M3/M4).

### N-013 · Cloud backup & sync backend (Supabase)
- **User problem:** Multi-device and team use (G-3 later).
- **Fit:** Adds auth, Postgres mirror of the schema, `updatedAt`/`deletedAt` columns for sync, conflict policy. Large architectural step; do only after N-003 proves the export format and after the data model stabilises (N-001, N-002, N-010).
- **Scores:** Impact 4 (later) · Effort XL · Confidence 2 · Fit 3 today
- **Recommendation:** **Later** (M4) — design spike only for now.

### N-014 · Property / listing records
- **Recommendation:** **Don't do now.** Tempting for a real-estate broker but doubles the domain model before the contact/notes core is solid; revisit after N-010 shows demand.

---

## 6.3 Prioritisation matrix

Rank = Impact × Fit ÷ effort-weight (S=1, M=2, L=3, XL=5), then confidence.

| Rank | ID | Item | Impact | Effort | Conf. | Fit | Recommendation | Milestone |
|---|---|---|---|---|---|---|---|---|
| 1 | I-001 | Startup guard | 5 | S | 5 | 5 | Do now | M0 |
| 2 | I-006 | Reminder correctness | 5 | S | 5 | 5 | Do now | M0 |
| 3 | I-002 | Notes-first + safe re-review | 5 | M | 5 | 5 | Do now | M0 |
| 4 | I-003 | Release readiness | 4 | S | 5 | 4 | Do now | M0 |
| 5 | I-004 | Privacy & logging hygiene | 4 | S | 5 | 4 | Do now | M0 |
| 6 | N-004 | Quick actions | 4 | S | 5 | 5 | Do now | M2 |
| 7 | N-011 | AI fallback chain | 3 | S | 5 | 5 | Do now | M2 |
| 8 | N-008 | Follow-up nudges | 3 | S | 4 | 5 | Do now | M2 |
| 9 | N-006 | Daily briefing | 3 | S | 4 | 5 | Do now | M2 |
| 10 | I-007 | Debug-only seeding | 3 | S | 5 | 4 | Do now | M0 |
| 11 | I-009 | Bundle font | 2 | S | 5 | 4 | Do now | M0 |
| 12 | I-017 | Overlay/prompt gating | 3 | S | 4 | 4 | Do now | M0 |
| 13 | N-003 | Backup/export/restore | 5 | M | 5 | 5 | Do now | M2 |
| 14 | I-005 | Native call queue + boot | 5 | M | 4 | 5 | Do now | M1 |
| 15 | N-001 | Unassigned calls inbox | 4 | M | 5 | 5 | Do now | M1 |
| 16 | N-002 | Task due dates | 4 | M | 4 | 5 | Do now | M1 |
| 17 | I-008 | Schema v2 + migrations | 4 | M | 4 | 5 | Do now | M1 |
| 18 | I-012 | Tests + CI | 4 | M | 5 | 4 | Do now | M0 |
| 19 | I-013 | Contact CRUD + entry points | 4 | M | 5 | 4 | Do now | M1 |
| 20 | I-014 | Polish batch | 3 | M | 5 | 4 | Do now | M0/M2 |
| 21 | I-010 | Phonebook cache | 3 | M | 4 | 4 | Do next | M1 |
| 22 | N-007 | Call-log import | 3 | M | 4 | 4 | Do next | M2 |
| 23 | I-015 | Remove unsupported platforms | 2 | S | 5 | 3 | Do next | M1 |
| 24 | I-011 | Data-change notifier | 4 | L | 4 | 4 | Do next | M1 |
| 25 | I-016 | Play-compat spike | 4 | L | 3 | 4 | Do next | M2 |
| 26 | N-005 | Voice notes | 5 | L | 3 | 4 | Do next | M3 |
| 27 | N-009 | Global search | 3 | M | 4 | 4 | Later | M3 |
| 28 | I-018 | Profile/dark/l10n scaffold | 2 | M | 4 | 3 | Later | M3 |
| 29 | N-010 | Pipeline & tags | 4 | L | 3 | 4 | Later | M3 |
| 30 | N-012 | Amharic | 3 | L | 4 | 4 | Later | M3/M4 |
| 31 | I-019 | Encryption / app lock | 3 | M | 3 | 3 | Later | M4 |
| 32 | N-013 | Supabase sync | 4 | XL | 2 | 3 | Later (spike) | M4 |
| 33 | N-014 | Property records | 2 | XL | 2 | 2 | Don't do now | — |

**Quick wins (high impact, ≤ ½ day each):**
1. **I-006 / T-005** — next-hour default + past-time guard: turns "reminders that never fire" into reminders that fire.
2. **N-004 / T-025** — Call / WhatsApp / Telegram buttons on the contact header.
3. **I-001 / T-002** — startup guard; removes the only "app never opens" failure mode.
