# 02 — Findings register

Severity: **Critical** = data loss, security breach or outage risk *now* · **High** = likely user-visible failure, blocked distribution, or privacy exposure · **Medium** = wrong behaviour or fragility in a real flow · **Low** = quality/UX/debt.
Effort: **S** < ½ day · **M** ½–2 days · **L** 2–5 days · **XL** > 5 days (must be split).
Sorted by severity, then cheapest first. Line references are to the working tree reviewed on 2026-09-28.

---

## Critical

### F-001 · Re-running AI Review on an existing note deletes its completed tasks; the whole save is non-transactional
- **Category:** Data integrity
- **Severity:** Critical · **Effort:** M · **Confidence:** Verified
- **Evidence:** `lib/features/notes/screens/ai_review_screen.dart:267-274`
  ```dart
  final oldTodos = await _todoRepo.getByNoteId(finalNoteId);
  for (final t in oldTodos) { await _todoRepo.delete(t.id); }
  final oldReminders = await _reminderRepo.getByNoteId(finalNoteId);
  for (final r in oldReminders) { await NotificationService().cancelReminder(r.id); await _reminderRepo.delete(r.id); }
  ```
  followed by sequential `insert`s (≈`:281-309`) with no `db.transaction`. The path is reachable for any existing note because `AddNoteScreen` accepts a `Note` argument and forwards `noteId` to AI Review (`add_note_screen.dart:36-39, 95-103`).
- **Impact:** Editing an old note and re-reviewing it wipes every task that came from that note, including ones already ticked off (with `completedAt` history), and replaces them with whatever the LLM returns this time. A crash or exception between the deletes and the inserts leaves the note with no tasks at all. Likelihood: every re-review; severity: silent loss of work history.
- **Recommended fix:** Never delete completed todos; upsert open todos by title match; wrap the save in `DatabaseHelper().database.then((db) => db.transaction(...))`; ask the user before replacing anything. See T-004.

---

## High

### F-002 · Startup awaits with no error handling → blank screen on any init failure
- **Category:** Reliability · **Severity:** High · **Effort:** S · **Confidence:** Verified
- **Evidence:** `lib/main.dart:26-42` — `await SeedData.seedIfNeeded(); await NotificationService().init(); await NotificationService().rescheduleAll(); … await _restoreCallDetection(); runApp(...)`. `NotificationService.init()` calls `tz.getLocation(timezoneInfo.identifier)` (`notification_service.dart:29-30`), which throws `LocationNotFoundException` for identifiers not in the bundled tz database; `seedIfNeeded` opens SQLite; neither is caught.
- **Impact:** Any exception (unknown timezone id on some OEM ROMs, disk full, plugin registration failure on a new platform) means the app shows the splash colour forever with no message. Likelihood low per device but catastrophic when it happens, and impossible for the user to diagnose.
- **Recommended fix:** `runZonedGuarded`, wrap each init step in try/catch with `debugPrint`, fall back to `tz.UTC`, and render a minimal "startup failed — Reset data / Continue" screen if the DB cannot open. See T-002.

### F-003 · A note can only be saved if the AI call succeeds
- **Category:** UX / Data · **Severity:** High · **Effort:** M · **Confidence:** Verified
- **Evidence:** `add_note_screen.dart:83-103` — the only action is "AI Review", which pushes `AppRoutes.aiReview`. `ai_review_screen.dart:158-181` — no key → dialog with "Skip for now" (pops) or "Enter API Key"; `:365-378` — on error the only button is "Retry"; the save bar is hidden while `_aiError != null` (`bottomNavigationBar: !_isProcessing && _aiError == null …`, ≈`:517`).
- **Impact:** Offline, out of quota (Groq free tier has daily caps), invalid key, or provider outage ⇒ the broker cannot persist the note at all. The text survives only while `AddNoteScreen` stays on the stack. High likelihood in Addis Ababa mobile-data conditions.
- **Recommended fix:** Persist the note immediately (raw text, empty summary) before calling the AI; make AI enrichment retryable later from note detail; add "Save without AI" on the error state. See T-003.

### F-004 · Reminders set in the past are accepted and silently never fire
- **Category:** Reliability · **Severity:** High · **Effort:** S · **Confidence:** Verified
- **Evidence:** `calendar_screen.dart:398` `TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);` with `initialDate: _selectedDay` (today) and no validation in the save handler (`:493-513`). `notification_service.dart:127-129` `if (reminder.completed || reminder.dateTime.isBefore(DateTime.now())) return;`. `reminder_detail_screen.dart:114-129` (`_saveChanges`) and `ai_review_screen.dart` ≈`:200-219` (`_pickDateTime` allows `firstDate: now − 1 day`) have the same gap.
- **Impact:** Any reminder added after 09:00 for "today" (the default) is created already-overdue and never notifies; the user believes it is set. Very likely in daily use.
- **Recommended fix:** Default to the next full hour; block or confirm past times; surface "scheduled / not scheduled" state. See T-005.

### F-005 · Client data leaves the device without consent; sensitive values are logged in release builds
- **Category:** Security / Privacy · **Severity:** High · **Effort:** S · **Confidence:** Verified
- **Evidence:** `ai_service.dart:228-242` sends the full note, the contact's name, the last three summaries and open task titles to the configured provider; no consent/notice anywhere in the UI (grep for "privacy"/"consent" = 0 hits). `ai_service.dart:271` `debugPrint('AiService [...] response: $content')` and `:278` log the response body; `call_matching_service.dart:257,269,279` log phone numbers and contact names. `debugPrint` is not removed in release builds (it is a throttled `print`).
- **Impact:** Broker's client conversations are processed by a third party under that provider's terms (Groq: no training; OpenRouter: depends on upstream) without the user opting in; logcat on a shared/rooted device or a bug report exposes client names and numbers.
- **Recommended fix:** One-time "AI processing notice" with provider name and a link, stored as a pref; gate all logs behind `kDebugMode` via a tiny `AppLog` wrapper; never log note bodies. See T-006, T-024.

### F-006 · Release build is signed with the debug keystore and shipped with placeholder identity
- **Category:** Production readiness · **Severity:** High · **Effort:** S · **Confidence:** Verified
- **Evidence:** `android/app/build.gradle.kts:35-39` `release { signingConfig = signingConfigs.getByName("debug") }` with the template TODO; `AndroidManifest.xml:21` `android:label="smart_broker"`; `web/manifest.json:8` "A new Flutter project"; no `android:allowBackup`/`dataExtractionRules` set (defaults to backing up the SQLite DB to the user's Google account).
- **Impact:** APK cannot be updated in place once a real keystore is introduced (different signature ⇒ uninstall/reinstall, losing the local DB — the only copy of the data). Launcher shows "smart_broker". Backup of client data happens implicitly.
- **Recommended fix:** `key.properties` + `signingConfigs.release` (already gitignored `android/.gitignore:12`), proper label/icon, explicit backup rules. See T-007.

### F-007 · Calls that happen while the app process is dead are never logged
- **Category:** Reliability · **Severity:** High · **Effort:** M · **Confidence:** Verified
- **Evidence:** `CallDetectionService.kt:93` `Handler(Looper.getMainLooper()).post { eventSink?.invoke(data) }` and `:221` `eventSink?.invoke(eventData)` — events are delivered only if a Dart listener is attached; nothing is persisted. `CallDetectionPlugin.onCancel` nulls the sink (`:130-132`). The foreground notification still says "Call detection active" (`buildNotification`, `.kt:241-253`). No `BOOT_COMPLETED` receiver restarts the service (the only receivers are the notifications plugin's, `AndroidManifest.xml:51-57`).
- **Impact:** After Android kills the app (common on Samsung battery optimisation) or after reboot, every call is lost until the app is opened, while the persistent notification claims otherwise. Undermines the core promise of the product.
- **Recommended fix:** Persist `call_logged` events natively (JSON list in SharedPreferences) when no sink is attached; drain them from Dart on `startListening()`; add a boot receiver that restarts the service when `call_detection_enabled` is true. See T-017.

### F-008 · Required permissions are Google Play–restricted
- **Category:** Reliability (distribution) · **Severity:** High · **Effort:** L · **Confidence:** Inferred (policy knowledge; code verified)
- **Evidence:** `AndroidManifest.xml:11-12,18` `READ_PHONE_STATE`, `READ_CALL_LOG`, `SYSTEM_ALERT_WINDOW`; `CallDetectionService.kt:176-224` depends on `CallLog.Calls` for number/duration.
- **Impact:** Google Play's Call Log permission policy only allows `READ_CALL_LOG` for apps that are the default phone/assistant handler or have an approved exception; a Play submission would be rejected, restricting distribution to side-loading. `SYSTEM_ALERT_WINDOW` requires a declaration form.
- **Recommended fix:** Time-boxed spike: evaluate `CallScreeningService` + `ROLE_CALL_SCREENING` (gives incoming numbers without call-log permission), `InCallService`/default-dialer role, or accepting side-load distribution with an in-app APK updater. Record as ADR. See T-031.

### F-009 · 35 files of changes are uncommitted and have never been compiled
- **Category:** DX / process · **Severity:** High · **Effort:** S · **Confidence:** Verified
- **Evidence:** `git status --short | wc -l` → 35 (Dart, `AndroidManifest.xml`, `CallDetectionService.kt`, `CallDetectionPlugin.kt`, `README.md`, deletions of `lib/overlay_main.dart`, `test/widget_test.dart`, `month_view_src.dart`). No Flutter toolchain was available to the reviewer; the last device run predates the overlay/native edits.
- **Impact:** A single compile error (e.g. an API-name mismatch in `flutter_overlay_window` calls, Kotlin receiver flags) blocks the whole app; changes can't be bisected.
- **Recommended fix:** Run `flutter pub get && flutter analyze && flutter test && flutter build apk --debug` on the Windows machine, fix, and commit in logical chunks. See T-001.

---

## Medium

### F-010 · Demo data is seeded into the production database; mock data contains real-looking PII
- **Category:** Data integrity · **Severity:** Medium · **Effort:** S · **Confidence:** Verified
- **Evidence:** `seed_data.dart:14-19` runs whenever `contacts` is empty, in every build mode; `main.dart:28`. `mock_contacts.dart:4-13` — `'Michael Nigusse', '+251900000000', 'michael@hilcoeschool.com'`.
- **Impact:** A fresh install starts with 8 fake contacts, notes and reminders (which also get scheduled as notifications); "Reset data" (if implemented) would re-seed. A personal-looking identity is committed to the repo.
- **Fix:** Seed only when `kDebugMode`, expose "Load demo data" in Developer Tools, replace mock identities with obviously fictional ones. See T-008.

### F-011 · No schema migration path and no indexes
- **Category:** Data integrity / Performance · **Severity:** Medium · **Effort:** M · **Confidence:** Verified
- **Evidence:** `database_helper.dart:22` `version: 1`; `:106-108` empty `_onUpgrade`; `:37-105` no `CREATE INDEX`; hot queries filter by `contactId`, `noteId`, `dateTime`, `timestamp`, `isCompleted` (`*_repository.dart`).
- **Impact:** Every upcoming feature (due dates, unassigned calls, tags) needs a migration; without a versioned pattern the first one risks data loss. Index absence is harmless at today's volume but becomes visible with call-log import.
- **Fix:** Versioned migration list executed in `_onUpgrade`; add indexes in v2. See T-014.

### F-012 · Duplicate contacts can be created for the same phone number
- **Category:** Data integrity · **Severity:** Medium · **Effort:** M · **Confidence:** Verified
- **Evidence:** schema has no unique constraint (`database_helper.dart:37-48`); `phone_contact_detail_screen.dart:36-61` inserts without lookup; `call_matching_service.dart:243-249` `_findContact` returns the first match, so duplicates diverge silently.
- **Impact:** Same client twice with split notes/tasks; call log attaches to whichever row sorts first.
- **Fix:** Store a normalised `phoneKey` column with a unique index; `ContactRepository.findByPhone`; merge-or-open on create. See T-014, T-015.

### F-013 · `pendingTasksCount` is denormalised and overwritten by full-row updates
- **Category:** Data integrity · **Severity:** Medium · **Effort:** S · **Confidence:** Verified
- **Evidence:** `contact_repository.dart:40-48` `db.update('contacts', contact.toMap(), …)` writes every column including `pendingTasksCount` from the in-memory object; count is recomputed only in `todo_repository.dart:_updateContactTasksCount`. Callers: `call_matching_service.dart:266-268`, `ai_review_screen.dart` ≈`:312-317` (the `lastInteraction` bump after save).
- **Impact:** A stale `Contact` object (loaded before tasks changed) resets the count; "Has Tasks" filter and badges drift.
- **Fix:** Compute counts with a subquery in `ContactRepository.getAll` (or update only changed columns). See T-015.

### F-014 · `cancelAll()` on every launch dismisses live notifications; notification IDs derive from `String.hashCode`
- **Category:** Reliability · **Severity:** Medium · **Effort:** S · **Confidence:** Verified
- **Evidence:** `notification_service.dart:189` `await _plugin.cancelAll();` inside `rescheduleAll()` called from `main.dart:31`; IDs at `:117,132,184` use `id.hashCode.abs()`.
- **Impact:** Opening the app by any other means than tapping the post-call prompt removes that prompt from the shade; a hash collision (two UUIDs, 32-bit space) cancels the wrong reminder; Dart does not guarantee `String.hashCode` stability across VM versions, so an app update could orphan scheduled alarms.
- **Fix:** Cancel only reminder-channel IDs you know about (store the numeric id in the `reminders` row, v2 migration) and stop calling `cancelAll`. See T-005.

### F-015 · UI font is downloaded from Google at runtime
- **Category:** Performance / Privacy · **Severity:** Medium · **Effort:** S · **Confidence:** Verified
- **Evidence:** `app_theme.dart:48` `GoogleFonts.interTextTheme()`; `pubspec.yaml` has no `fonts:` section.
- **Impact:** First launch (or after cache eviction) on a slow/offline connection shows the fallback font then reflows; an external request to Google on every cold start.
- **Fix:** Bundle Inter TTFs under `assets/fonts`, declare in `pubspec.yaml`, set `GoogleFonts.config.allowRuntimeFetching = false`. See T-009.

### F-016 · Whole phonebook is re-read (and permission re-requested) on every Contacts load
- **Category:** Performance · **Severity:** Medium · **Effort:** M · **Confidence:** Verified
- **Evidence:** `contact_merge_service.dart:19-20` `if (await _phoneService.requestPermission()) phoneContacts = await _phoneService.getContacts();` called from `contacts_screen.dart:55-57` on init, on every `.then((_) => _loadData())` (`:305,312`) and pull-to-refresh (`:291`).
- **Impact:** With a few thousand phonebook entries each return to the tab costs a noticeable spinner; requesting permission inside a data call surfaces the OS dialog at odd moments.
- **Fix:** Cache phonebook in memory with a short TTL + manual refresh; request permission explicitly from an onboarding step. See T-018.

### F-017 · No state layer: every screen re-queries after every `pop`; lists go stale
- **Category:** Architecture · **Severity:** Medium · **Effort:** L · **Confidence:** Verified
- **Evidence:** pattern `Navigator.pushNamed(...).then((_) => _loadData())` at `home_screen.dart:190,198`, `contacts_screen.dart:305,312`, `contact_detail_screen.dart:213`; stale case: `phone_contact_detail_screen.dart:57-60` `popAndPushNamed` fires the contacts screen's reload before the new detail screen is used, so later edits are not reflected until manual refresh. `IndexedStack` tabs (`main_shell.dart:29-33`) never reload when switching tabs.
- **Impact:** Home stats and Contacts badges show stale numbers after work done in another tab; every navigation costs a full reload.
- **Fix:** Introduce a minimal `DataChangeNotifier` (a `ChangeNotifier` singleton fired by repositories) that screens subscribe to; no new dependency required. See T-016.

### F-018 · Test coverage ≈ 3 files; no widget/repository/native tests; no CI
- **Category:** Testing · **Severity:** Medium · **Effort:** M · **Confidence:** Verified
- **Evidence:** `test/` contains 2 files / 25 tests (`grep -c "test("`); `.github/` absent; `analysis_options.yaml` default rules; no `sqflite_common_ffi` in `pubspec.yaml`.
- **Impact:** Regressions (like the bulk-complete toggle bug fixed this session) reach the device unnoticed.
- **Fix:** Repository tests on in-memory SQLite, `http.testing.MockClient` for `AiService`, widget tests for the two main flows, GitHub Actions gate. See T-011, T-012.

### F-019 · Dead controls and an unreachable screen; no contact CRUD
- **Category:** UX · **Severity:** Medium · **Effort:** M · **Confidence:** Verified
- **Evidence:** `contacts_screen.dart:155` "Add contact" `onPressed: () {}`; `contact_detail_screen.dart:140` "⋯" `onPressed: () {}`; `settings_screen.dart:302,400,538,552` (Theme, Clear AI Cache, Debug Menu, Reset Data) `onTap: () {}`; `NotesListScreen` registered (`AppRoutes.notesList` in the route table, `main.dart:117-128`) but never navigated to; `AppRoutes.contacts`/`calendar` constants unused (`app_routes.dart:7,15`).
- **Impact:** The only ways to get a contact into the CRM are a phone call or the phonebook; no edit/delete; controls that do nothing erode trust.
- **Fix:** Contact form (create/edit), delete with cascade warning, notes-list entry on Home, remove or implement the settings tiles. See T-019, T-020.

### F-020 · Tasks have no due date; "overdue" means "created more than 7 days ago"
- **Category:** UX / Data model · **Severity:** Medium · **Effort:** M · **Confidence:** Verified
- **Evidence:** `todo_repository.dart:22-25` `where = 't.isCompleted = 0 AND t.createdAt < ?'` with a 7-day cutoff; `home_screen.dart:176-179` same rule; schema has no `dueAt` (`database_helper.dart:64-77`).
- **Impact:** Brokers work to dates ("send offer by Thursday"); the AI already extracts dates for reminders but tasks lose them.
- **Fix:** Add nullable `dueAt`, capture it in AI review and the add-task sheets, define overdue = `dueAt < now`. See T-022.

### F-021 · Every unknown caller becomes a contact; overlay and prompt fire for all callers
- **Category:** UX / Data integrity · **Severity:** Medium · **Effort:** M · **Confidence:** Verified
- **Evidence:** `call_matching_service.dart:270-279` creates a contact named after the number; `_startOverlay` (`:158-190`) is invoked for every ringing/offhook state regardless of match; post-call prompt gated only by duration (`:299-303`).
- **Impact:** Spam and personal calls pollute the CRM and interrupt with an overlay; the user explicitly asked for an "unassigned" alternative.
- **Fix:** Unassigned-calls inbox (new table + screen), overlay only for known contacts by default (setting), prompt only for known/assigned. See T-013, T-021.

### F-022 · `setState` after `await` without `mounted` guards
- **Category:** Reliability · **Severity:** Medium · **Effort:** S · **Confidence:** Verified
- **Evidence:** `notes_list_screen.dart:66-69` (`_performSearch`), `note_detail_screen.dart:121-125` (`_saveEdits`), `reminder_detail_screen.dart:106-112` (`_cancelEditMode` called after awaits in `_saveChanges :123-127`), `:187` (`_pickDateTime`).
- **Impact:** Leaving the screen while a query/picker is pending throws "setState() called after dispose()"; in release it is swallowed but the disposed controllers in `reminder_detail_screen.dart:56-62` can be double-disposed.
- **Fix:** `if (!mounted) return;` after each await; move controller lifecycle to `initState/dispose`. See T-010.

### F-023 · Tapping a task on Home completes it; reminder cards on Contact/Note detail are inert
- **Category:** UX · **Severity:** Medium · **Effort:** S · **Confidence:** Verified
- **Evidence:** `home_screen.dart:200-208` passes `showChevron: true` and only `onChanged`; `todo_tile.dart:136-143` `onTap: … onChanged?.call(!todo.isCompleted)`. `contact_detail_screen.dart:749` `ReminderCard(reminder: r)` without `onTap`/`onComplete`; same in `note_detail_screen.dart` reminder section.
- **Impact:** Accidental completion with no undo on Home; reminders cannot be opened from the contact they belong to.
- **Fix:** Chevron rows navigate; pass `onTap`/`onComplete`. See T-032.

### F-024 · Native call-log heuristic is fragile
- **Category:** Reliability · **Severity:** Medium · **Effort:** M · **Confidence:** Verified
- **Evidence:** `CallDetectionService.kt:166-172` waits a fixed 1500 ms after IDLE then `fetchLastCallFromLog` reads only the newest row (`:181-190`); dedup uses the in-memory field `lastProcessedCallDate` (declared near the top of the class, ≈`:41`) which resets on service restart; `calls` table has no uniqueness (`database_helper.dart:95-104`).
- **Impact:** Slow OEM call-log writes ⇒ the previous call is re-logged (duplicate rows) or the new one missed; after a service restart the last call can be logged again.
- **Fix:** Query rows with `DATE > lastSeen` persisted in prefs, retry once after 3 s if none newer, dedupe in Dart by (number, timestamp). See T-017.

---

## Low

### F-025 · `lastInteraction` only changes on calls and AI saves
- **Category:** Data · **Effort:** S · **Confidence:** Verified
- **Evidence:** task creation paths do not touch it: `contact_detail_screen.dart:256-266`, `tasks_screen.dart:469-481`; note edits in `note_detail_screen.dart:115-127`.
- **Impact:** "Recent" filter (`contacts_screen.dart:98-105`) and Home "Recent contacts" (`home_screen.dart:86-87`) mis-order. See T-029.

### F-026 · Date/format glitches
- **Category:** UX · **Effort:** S · **Confidence:** Verified
- **Evidence:** `contact_detail_screen.dart:308-314` and `contact_card.dart:116-124` use `difference.inDays == 0` for "Today" (23:00 yesterday viewed at 01:00 ⇒ "Today"); `calendar_screen.dart:321` "No events today" for any selected day; `calendar_screen.dart:146` `lastDay: 2030-12-31` vs date picker `:447` `lastDate: DateTime(2100)` (and `focusedDay` asserts after 2030).
- **Fix:** Reuse the calendar-date comparison in `notes_list_screen.dart:96-104`; dynamic `lastDay`. See T-032.

### F-027 · `TextEditingController`s created in sheets/dialogs are never disposed
- **Category:** Tech debt · **Effort:** S · **Confidence:** Verified
- **Evidence:** `contact_detail_screen.dart:599`, `todo_tile.dart:151`, `calendar_screen.dart:396` (`_AddReminderSheetState` has no `dispose`), `tasks_screen.dart` add sheet.
- **Fix:** Dispose after the sheet/dialog future completes or move into `State.dispose`. See T-010.

### F-028 · Hardcoded user name, English-only strings, inert Theme tile
- **Category:** UX / i18n · **Effort:** M · **Confidence:** Verified
- **Evidence:** `home_screen.dart:118` `'Michael'`; no `flutter_localizations`/`l10n.yaml`; `settings_screen.dart:298-303` Theme tile shows "Light (Default)" and does nothing; `app_theme.dart` has only `lightTheme`.
- **Fix:** Profile name setting; l10n scaffold (Amharic later); dark theme. See T-036, T-037.

### F-029 · Search is not normalised; `LIKE` patterns are not escaped
- **Category:** UX · **Effort:** S · **Confidence:** Verified
- **Evidence:** `contacts_screen.dart:86-89` `c.phoneNumber.contains(_searchQuery)` on raw stored format; `contact_repository.dart:22-29`, `note_repository.dart:43-58` interpolate `'%$query%'` without escaping `%`/`_`.
- **Fix:** Match on `PhoneContact.matchKey`; escape wildcards. See T-032, T-034.

### F-030 · Unsupported platform scaffolding is checked in
- **Category:** Tech debt · **Effort:** S · **Confidence:** Verified
- **Evidence:** `web/`, `linux/`, `macos/`, `windows/` exist; `main.dart:1` and `settings_screen.dart:4` import `dart:io`; sqflite has no web/desktop implementation in the lockfile.
- **Impact:** Contributors may pick "Chrome"/"Windows" as a run target and hit runtime crashes (this happened during this session). See T-023.

### F-031 · Icon-only controls lack semantics
- **Category:** Accessibility · **Effort:** S · **Confidence:** Verified
- **Evidence:** `main_shell.dart:90-118` `_NavBarItem` is a `GestureDetector` around an `Icon` with no `Semantics`/`Tooltip`; repo-wide only 3 `tooltip:`/`Semantics(` usages.
- **Fix:** Wrap in `Semantics(button: true, label: …)`; add tooltips to icon buttons. See T-032.

### F-032 · Ad-hoc logging, no crash reporting
- **Category:** Observability · **Effort:** M · **Confidence:** Verified
- **Evidence:** `notification_service.dart:167` `print(...)`; services swallow exceptions into `debugPrint` (`call_matching_service.dart:108,306`); no error-reporting SDK; no `FlutterError.onError` handler.
- **Fix:** `AppLog` wrapper (`dart:developer log`), `FlutterError.onError` + `PlatformDispatcher.onError` → local ring-buffer log viewable in Developer Tools (no third-party SDK to respect the zero-cost/privacy constraint). See T-024.

### F-033 · Minor code-quality debt (grouped)
- **Category:** Tech debt · **Effort:** S · **Confidence:** Verified
- **Evidence:** (a) `todo_repository.dart:15-41` builds SQL by string concatenation from internal constants — safe today, injection-prone pattern; (b) `contact_detail_screen.dart:755-758` `capitalize()` indexes `this[0]` and throws on empty strings; (c) `tasks_screen.dart:25-26` magic strings `'all' | 'pending' | 'completed' | 'overdue'` instead of an enum (contrast `ContactFilter` enum in `contacts_screen.dart`); (d) `android/gradle.properties:1` `-Xmx8G -XX:MaxMetaspaceSize=4G` fails on machines with < 8 GB free; (e) two preference backends (`SharedPreferences` in `settings_service.dart` vs `SharedPreferencesAsync` in `call_overlay_state.dart`/`overlay_draft_service.dart`) — intentional for cross-engine reads but undocumented; (f) `AppRoutes.contacts`/`calendar` unused. See T-010, T-032.

### F-034 · Database is unencrypted at rest; no app lock
- **Category:** Security · **Effort:** M · **Confidence:** Verified
- **Evidence:** `database_helper.dart:18-20` plain `openDatabase` in app-private storage; no biometric/PIN gate.
- **Impact:** Relies entirely on Android file-based encryption and the device lock; a rooted/ADB-backup extraction exposes all client notes. Acceptable for a personal device today; matters before multi-user or Play distribution. See T-039.
