# SmartBroker — System review & implementation plan

Review date: 2026-09-28 · Scope: the `smart_broker` Flutter/Android repository, working tree at commit `3c9ca74` **plus 35 uncommitted files** · Reviewer role: takeover review (read-only; no project file was modified — the only additions are the documents in this folder).

| File | Content |
|---|---|
| `00-README.md` (this file) | Executive summary, top-10 starting tasks, traceability matrix, assumptions & open questions, discovery log |
| `01-current-state.md` | Phase 2 — stack, architecture diagram, module map, data model, feature inventory, flows, interface inventory, config, build/test results |
| `02-findings.md` | Phase 3 — 34 findings (F-001…F-034) with evidence, severity, effort |
| `03-recommendations.md` | Phase 4 — 19 improvements (I-001…I-019), 14 feature proposals (N-001…N-014), prioritisation matrix, quick wins |
| `04-implementation-plan.md` | Phase 5 — milestones M0…M4, Gantt/dependency graph, 39 tasks (T-001…T-039) in the full template, Definition of Done |
| `05-test-plan.md` | Phase 5 — test strategy, 168 test cases (TC-001…TC-168), infrastructure, non-functional tests, CI gates |

---

## Executive summary

SmartBroker is a single-user, offline-first Android CRM for a broker, written in Flutter (Dart 3.11 / Flutter ≥3.38.4) with a Kotlin foreground service for call detection and a floating call-notes overlay. Contacts, notes, tasks, reminders and calls live in an on-device SQLite database; notes are enriched by an LLM (Groq by default, OpenAI-compatible, user-supplied free key); reminders fire as local notifications. There is no backend, no accounts and no sync.

It is a **late prototype**: the layering is clean (models → repositories → services → screens), the domain model is small and sensible, and the core note→AI→tasks/reminder loop works on a real device today. But it is not yet safe to rely on: re-reviewing a note silently deletes completed tasks (F-001), a note cannot be saved unless the AI call succeeds (F-003), any startup failure leaves a blank screen (F-002), reminders set after 09:00 for "today" never fire (F-004), calls made while the app process is dead are lost (F-007), and the release build is signed with the debug keystore (F-006). Client notes are sent to a third-party model without a consent notice and sensitive values are logged in release builds (F-005). The required call-log permissions are Google Play–restricted (F-008), which shapes the distribution strategy. Test coverage is three pure-Dart files, there is no CI, and the most recent large batch of changes (overlay rework, native service changes) is uncommitted and has never been compiled (F-009).

**Health (1–10):** architecture 5 · code quality 6 · security/privacy 5 · test coverage 2 · performance 6 · dev experience 4 · production readiness 3. Details and justification in `01-current-state.md §1`.

**Plan in one line:** two weeks to stabilise and secure (M0: build+commit, startup guard, notes-first save, safe re-review, reminder validation, consent+logging, signing, tests+CI), three weeks of foundations (M1: schema v2 with migrations, unassigned-calls inbox, task due dates, native call-event queue, contact CRUD, reactive refresh), three weeks of core features (M2: backup/restore, quick actions, daily briefing, AI fallback, nudges, call-log import, Play-compatibility decision), then growth (M3: voice notes, search, tags/pipeline, dark mode, Amharic) and, later, sync and encryption (M4).

---

## Top 10 tasks to start with (in order)

1. **T-001** Build, verify and commit the current working tree — everything else depends on a known-good commit.
2. **T-002** Guard app startup (`main()` try/catch, timezone fallback, error screen) — removes the only "app never opens" mode.
3. **T-011** Test harness (in-memory SQLite repos, `MockClient` AI) — the safety net for all data-layer changes.
4. **T-012** GitHub Actions CI (format, analyze, test, coverage gate, debug APK).
5. **T-003** Notes-first save — the note is persisted before the AI call; AI becomes retryable enrichment.
6. **T-004** Non-destructive, transactional AI re-review — keeps completed tasks.
7. **T-005** Reminder correctness — next-hour default, past-time guard, stable notification ids, no `cancelAll()`.
8. **T-006** AI consent notice + release-safe logging.
9. **T-007** Release signing, app identity, backup rules (do this before the first "real" install).
10. **T-014** Schema v2 with a versioned migration framework, indexes, phone key, due dates, unassigned-calls table.

Quick wins if a spare hour appears: **T-009** bundle the font, **T-013** overlay only for known contacts, **T-025** Call/WhatsApp/Telegram buttons.

---

## Traceability matrix

Every Critical/High finding maps to a task in M0–M2; every task maps to at least one test case.

### Findings → tasks → test cases

| Finding | Sev. | Task(s) | Test case(s) |
|---|---|---|---|
| F-001 | Critical | T-004 | TC-013…TC-017 |
| F-002 | High | T-002 | TC-004…TC-007 |
| F-003 | High | T-003 | TC-008…TC-012 |
| F-004 | High | T-005 | TC-018…TC-020, TC-023 |
| F-005 | High | T-006, T-024 | TC-024…TC-027, TC-106 |
| F-006 | High | T-007 | TC-028…TC-030 |
| F-007 | High | T-017 | TC-070…TC-075 |
| F-008 | High | T-031 | TC-135, TC-136 |
| F-009 | High | T-001 | TC-001…TC-003 |
| F-010 | Medium | T-008 | TC-031…TC-033 |
| F-011 | Medium | T-014 | TC-055, TC-057, TC-060 |
| F-012 | Medium | T-014, T-015 | TC-061, TC-064, TC-065 |
| F-013 | Medium | T-015 | TC-043, TC-062, TC-063 |
| F-014 | Medium | T-005 | TC-021, TC-022 |
| F-015 | Medium | T-009 | TC-034, TC-035 |
| F-016 | Medium | T-018 | TC-077…TC-080 |
| F-017 | Medium | T-016 | TC-066…TC-069 |
| F-018 | Medium | T-011, T-012 | TC-041…TC-050 |
| F-019 | Medium | T-019, T-020 | TC-081…TC-089 |
| F-020 | Medium | T-022 | TC-097…TC-102 |
| F-021 | Medium | T-013, T-021 | TC-051…TC-054, TC-090…TC-096 |
| F-022 | Medium | T-010 | TC-036, TC-037 |
| F-023 | Medium | T-032 | TC-137, TC-138 |
| F-024 | Medium | T-017 | TC-056, TC-073, TC-076 |
| F-025 | Low | T-029 | TC-127, TC-130 |
| F-026 | Low | T-032 | TC-139…TC-141 |
| F-027 | Low | T-010 | TC-039 |
| F-028 | Low | T-036, T-037 | TC-159…TC-164 |
| F-029 | Low | T-032, T-034 | TC-142, TC-143, TC-153 |
| F-030 | Low | T-023 | TC-103, TC-104 |
| F-031 | Low | T-032 | TC-144 |
| F-032 | Low | T-024 | TC-105, TC-107, TC-108 |
| F-033 | Low | T-010, T-032 | TC-038, TC-040, TC-145 |
| F-034 | Low | T-039 | TC-167, TC-168 |

### Improvements → tasks

| I-001 → T-002 | I-002 → T-003, T-004 | I-003 → T-007 | I-004 → T-006, T-024 | I-005 → T-017 |
|---|---|---|---|---|
| **I-006 → T-005** | **I-007 → T-008** | **I-008 → T-014, T-015** | **I-009 → T-009** | **I-010 → T-018** |
| **I-011 → T-016** | **I-012 → T-011, T-012** | **I-013 → T-019, T-020** | **I-014 → T-010, T-032** | **I-015 → T-023** |
| **I-016 → T-031** | **I-017 → T-013** | **I-018 → T-036, T-037** | **I-019 → T-039** | |

### New features → tasks

| N-001 → T-021 | N-002 → T-022 | N-003 → T-026 | N-004 → T-025 | N-005 → T-033 | N-006 → T-028 | N-007 → T-027 |
|---|---|---|---|---|---|---|
| **N-008 → T-029** | **N-009 → T-034** | **N-010 → T-035** | **N-011 → T-030** | **N-012 → T-037** | **N-013 → T-038** | **N-014 → none (don't do now)** |

### Tasks → test cases (summary)

T-001 TC-001…003 · T-002 TC-004…007 · T-003 TC-008…012 · T-004 TC-013…017 · T-005 TC-018…023 · T-006 TC-024…027 · T-007 TC-028…030 · T-008 TC-031…033 · T-009 TC-034…035 · T-010 TC-036…040 · T-011 TC-041…047 · T-012 TC-048…050 · T-013 TC-051…054 · T-014 TC-055…060 · T-015 TC-061…065 · T-016 TC-066…069 · T-017 TC-070…076 · T-018 TC-077…080 · T-019 TC-081…086 · T-020 TC-087…089 · T-021 TC-090…096 · T-022 TC-097…102 · T-023 TC-103…104 · T-024 TC-105…108 · T-025 TC-109…112 · T-026 TC-113…119 · T-027 TC-120…123 · T-028 TC-124…126 · T-029 TC-127…130 · T-030 TC-131…134 · T-031 TC-135…136 · T-032 TC-137…145 · T-033 TC-146…150 · T-034 TC-151…154 · T-035 TC-155…158 · T-036 TC-159…161 · T-037 TC-162…164 · T-038 TC-165…166 · T-039 TC-167…168.

---

## Assumptions & open questions

Every **[Assumed]** item, with the default chosen.

| # | Assumption / question I would have asked | Default used |
|---|---|---|
| A-1 | **Section 0 (product goals, team, constraints, out-of-scope) was not included in the brief.** What are the goals? | Derived G-1…G-5 in `03-recommendations.md`: never lose a client interaction; zero running cost; single broker/single phone now, team later; Ethiopian context (local/international numbers, Telegram/WhatsApp, intermittent data, Amharic later); solo part-time developer + AI assistant. |
| A-2 | Which revision to review — `HEAD` or the uncommitted working tree? | The working tree (it is the actual current system); flagged as F-009 with T-001 to commit it. |
| A-3 | Team capacity and timeline? | One developer, ~20 h/week; milestones sized accordingly (M0 2 wks, M1 3 wks, M2 3 wks, M3 4 wks). |
| A-4 | Test device and Android version? | Samsung phone on Android 13/14 (inferred from `OnBackInvokedCallback`/SmartClip log lines); Android 14 foreground-service rules assumed to apply. |
| A-5 | Distribution channel — Google Play or side-load? | Unknown; F-008 rated High and T-031 is a decision spike. Side-load is assumed acceptable until then. |
| A-6 | Is iOS a target? | No for now; `ios/` kept dormant, other platforms removed (T-023). |
| A-7 | Will the AI provider stay Groq? | Yes as default; provider abstraction and fallback chain (T-030) keep it swappable. Groq `whisper-large-v3-turbo` availability on the free tier is assumed for N-005 (verify in the feasibility step). |
| A-8 | Package versions for new dependencies (`sqflite_common_ffi`, `url_launcher`, `share_plus`, `file_picker`, `record`) | **[Inferred]** — listed with `^` ranges believed compatible with Flutter 3.38/Dart 3.11; each task says to run `flutter pub add` and accept the resolver's version. `intl 0.20.2` is assumed to be the version Flutter 3.38's `flutter_localizations` pins. |
| A-9 | Google Play call-log policy still restricts `READ_CALL_LOG` to default handlers | **[Inferred]** from policy knowledge; verify in T-031. |
| A-10 | Starting a foreground service from a `BOOT_COMPLETED` receiver is permitted on Android 14 for the `phoneCall` type | **[Inferred]**; verify on device in TC-075. |
| A-11 | `String.hashCode` stability across Dart versions | Not guaranteed by the language spec; T-005 replaces it with a stable hash regardless. |
| A-12 | Is the developer's real name/email in `mock_contacts.dart` intentional? | Treated as accidental PII (F-010); T-008 replaces it. |
| A-13 | Does the user want Amharic UI? | Assumed "eventually" (G-4); scheduled M3/M4. |
| A-14 | Will there be a keystore/backup process owner? | Assumed the developer; `docs/RELEASE.md` in T-007 documents it. |
| A-15 | Acceptable to delete `web/`, `linux/`, `macos/`, `windows/`? | Yes (recoverable with `flutter create`); T-023. |
| A-16 | The dependency audit could not be run (no toolchain reachable). Any known CVEs? | None identified by manual lockfile review; run `flutter pub outdated` in T-012's scheduled job. |

---

## Discovery log

Environment: Linux VM with the project folder mounted read/write (used read-only for this review, except for creating `docs/system-review/`), no Flutter/Dart SDK, Java 17 present, outbound HTTPS to `storage.googleapis.com` blocked by the egress proxy (HTTP 403). A cloud sandbox was also used to attempt a Flutter clone (`git clone --depth 1 -b stable https://github.com/flutter/flutter.git` succeeded; `flutter --version` failed on the Dart SDK download with `curl: (56) CONNECT tunnel failed, response 403`).

**Commands run (read-only):**
- `ls -la`, `find . -maxdepth 3 …` (tree excluding build/.dart_tool/.git/.gradle/ephemeral/.idea), `wc -l` over all Dart/Kotlin files (10,345 lines).
- `git log --format='%h %ad %an %s' --date=short` (3 commits), `git status --short | wc -l` (35), `git diff --stat`, `git log --name-only … | sort | uniq -c` (churn), `git ls-files` checks for `local.properties`/`.iml`/`.idea`/`.flutter-plugins-dependencies`.
- `awk` over `pubspec.lock` for every package version; `grep -A3 '^sdks:'`; `.metadata` revision.
- `grep -rn` for: `TODO|FIXME|HACK|XXX|@deprecated`, `onPressed: () {}` / `onTap: () {}`, `print(`/`debugPrint(`/`kDebugMode`, `transaction(`/`CREATE INDEX`, `Semantics(`/`tooltip:`, `findByPhoneNumber`, `allowBackup|enableOnBackInvokedCallback|android:label`, secrets patterns (`api[_-]?key|secret|token|password` with long literals — no hits), `.github`/`.gitlab-ci.yml` (absent), `darkTheme|ThemeMode`, `test(` counts (19 + 6).
- `which flutter dart java gradle adb` (only `java` found).
- `curl -I https://storage.googleapis.com/…` from the VM (403 from proxy) — recorded, not retried.

**Files read in full or in cited ranges:** `README.md`, `pubspec.yaml`, `pubspec.lock` (versions), `analysis_options.yaml`, `.gitignore`, `.metadata`; `android/app/build.gradle.kts`, `android/build.gradle.kts`, `android/settings.gradle.kts`, `android/gradle.properties`, `android/gradle/wrapper/gradle-wrapper.properties`, `android/.gitignore`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/…/MainActivity.kt`, `CallDetectionPlugin.kt`, `CallDetectionService.kt`; `ios/Runner/Info.plist` (usage strings); `web/manifest.json`; all of `lib/main.dart`, `lib/core/constants/app_routes.dart`, `lib/core/database/database_helper.dart`, `lib/core/database/seed_data.dart`, `lib/core/repositories/*.dart` (5), `lib/core/services/*.dart` (13), `lib/core/theme/app_theme.dart` (head), `lib/core/widgets/contact_card.dart`, `reminder_card.dart`, `todo_tile.dart`, `section_header.dart`, `empty_state_widget.dart` (via sub-agent), `lib/models/*.dart` (11), `lib/mock/mock_contacts.dart` (head) and counts of the other mocks; `lib/features/home/screens/main_shell.dart`, `home_screen.dart`; `lib/features/contacts/screens/contacts_screen.dart`, `contact_detail_screen.dart`, `phone_contact_detail_screen.dart`; `lib/features/notes/screens/add_note_screen.dart`, `ai_review_screen.dart`, `note_detail_screen.dart`, `notes_list_screen.dart`; `lib/features/todos/screens/tasks_screen.dart`; `lib/features/calendar/screens/calendar_screen.dart`, `reminder_detail_screen.dart`; `lib/features/calls/screens/call_overlay_screen.dart`; `lib/features/settings/screens/settings_screen.dart`; `test/call_detection_test.dart`, `test/ai_response_parser_test.dart`. Platform scaffolding under `linux/`, `macos/`, `windows/`, `web/` and `ios/` was surveyed by listing only.

**External references consulted (via a research sub-agent):** pub.dev + GitHub source of `flutter_overlay_window` 0.5.0 (manifest requirements, `overlayMain` lookup, `OverlayFlag` semantics, px/dp units, messaging), Groq documentation (models, deprecations, structured outputs, endpoints), and a comparison of free LLM API tiers (used for the provider choice recorded in `README.md`).

**Skipped / could not run:** `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build`, `dart format`, `dart pub outdated`, any Gradle task, any device interaction (the desktop-automation path would have required an interactive approval, which this one-shot brief ruled out).
