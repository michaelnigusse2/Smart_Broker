# SmartBroker

A modern, minimalist AI-assisted CRM application for brokers and professionals, built with Flutter.

> **Phase 1 — UI Skeleton**
> This release covers the complete, production-quality UI foundation using mock data. Backend integration, AI processing, and native Android services are planned for Phase 2.

---

## Overview

SmartBroker is a contact-centric mobile CRM designed to help brokers manage client relationships, track conversations, handle follow-up tasks, and organize reminders — all in one clean interface.

The design philosophy is **minimalist productivity**: inspired by tools like Notion and Linear, the UI favours generous whitespace, strong typography hierarchy, and a single Indigo accent colour over visual clutter.

---

## Screenshots

> Run the app locally to see the UI in action (see [Running Locally](#running-locally)).

---

## Features

### 📱 Navigation
- Floating glassmorphism bottom navigation bar with smooth icon transitions
- Persistent tab state using `IndexedStack`
- Named routing across all screens

### 🏠 Home Dashboard
- Time-aware greeting ("Good morning / afternoon / evening")
- Live stat pills — total contacts, pending tasks, upcoming reminders
- Upcoming reminders with overdue accent indicators
- Recent contacts with task-status dots
- Pending tasks checklist

### 👥 Contacts
- Searchable contact list with live search and a clear button
- **Functional filter system** (no backend required):
  - **All** — all contacts sorted by last interaction
  - **Recent** — contacts active within the last 7 days
  - **Has Tasks** — contacts with pending tasks, sorted by task count
  - **Overdue** — contacts linked to a past-due reminder
- Filter pills with badge counts for Has Tasks and Overdue
- Contact cards with Indigo avatar ring for contacts needing attention

### 👤 Contact Detail
- Pinned header: name, phone, last interaction
- Fluid collapsible sections (Notion-style):
  - **Notes** — timeline view with AI summary + raw note preview
  - **Tasks** — minimalist checkbox list
  - **Call History** — typed call log (incoming / outgoing / missed)
  - **Reminders** — compact event rows
- "Add Note" floating action button

### ✍️ Add Note
- Distraction-free, full-screen writing canvas
- One-tap hand-off to AI Review

### 🤖 AI Review
- Simulated AI processing with a minimal loading indicator
- Editable **Summary** text field
- Extracted **Action Items** checklist
- Toggleable **Suggested Reminder**
- "Save to Profile" commit action

### 📅 Calendar
- `table_calendar` integration with full custom cell rendering:
  - Today highlighted with a soft Indigo tint
  - Selected day with a solid Indigo circle
  - Event dots **always below** the date number (never overlapping)
- Tappable cells that update the event list below
- Timeline-style event list for the selected date

### ⚙️ Settings
- Appearance, AI integration, and developer tool sections
- Ready for Phase 2 configuration hooks

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Material 3) |
| Language | Dart |
| Typography | `google_fonts` — Inter |
| Calendar | `table_calendar` |
| Icons | `lucide_icons` |
| Date formatting | `intl` |
| State | Local `StatefulWidget` (Phase 1) |
| Data | Hardcoded mock data (`lib/mock/`) |

---

## Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── app_routes.dart         # All named route constants
│   ├── theme/
│   │   └── app_theme.dart          # AppTheme, AppColors, AppSpacing, AppRadius
│   └── widgets/                    # Reusable components
│       ├── constrained_layout.dart # Max-width wrapper (tablet/web safe)
│       ├── contact_card.dart
│       ├── empty_state_widget.dart
│       ├── info_chip.dart
│       ├── reminder_card.dart
│       ├── section_header.dart
│       └── todo_tile.dart
├── features/
│   ├── calendar/
│   │   └── screens/calendar_screen.dart
│   ├── contacts/
│   │   └── screens/
│   │       ├── contact_detail_screen.dart
│   │       └── contacts_screen.dart
│   ├── home/
│   │   └── screens/
│   │       ├── home_screen.dart
│   │       └── main_shell.dart     # Root scaffold + floating bottom nav
│   ├── notes/
│   │   └── screens/
│   │       ├── add_note_screen.dart
│   │       └── ai_review_screen.dart
│   └── settings/
│       └── screens/settings_screen.dart
├── mock/                           # All mock data (replace with repositories in Phase 2)
│   ├── mock_calls.dart
│   ├── mock_contacts.dart
│   ├── mock_notes.dart
│   ├── mock_reminders.dart
│   └── mock_todos.dart
├── models/                         # Domain models
│   ├── call_entry.dart
│   ├── contact.dart
│   ├── note.dart
│   ├── reminder.dart
│   └── todo_item.dart
└── main.dart
```

---

## Design System

### Colours
| Token | Hex | Usage |
|---|---|---|
| `primary` | `#4F46E5` | Accent, active states, selected nav |
| `background` | `#FAFAFA` | App scaffold background |
| `surface` | `#FFFFFF` | Card and panel backgrounds |
| `surfaceElevated` | `#F4F4F5` | Input fills, filter chips, avatars |
| `textPrimary` | `#111111` | Headings, labels |
| `textSecondary` | `#666666` | Metadata, subtitles |
| `textTertiary` | `#A1A1AA` | Timestamps, placeholders |
| `divider` | `#EAEAEA` | Separators |
| `error` | `#EF4444` | Overdue indicators |

### Spacing Scale
`4 → 8 → 12 → 16 → 24 → 32 → 48`

### Border Radius
`sm: 8` · `md: 12` · `lg: 16` · `xl: 24`

---

## Running Locally

**Prerequisites:** Flutter SDK ≥ 3.0, Android SDK (minSdk 21)

```bash
# 1. Clone the repository
git clone <repo-url>
cd smart_broker

# 2. Install dependencies
flutter pub get

# 3. Run in debug mode
flutter run
```

Choose your target device when prompted (Android emulator, Chrome, or Windows desktop).

> **Hot restart vs hot reload**
> If you change enum definitions or `main.dart`, always use **`R`** (hot restart) rather than `r` (hot reload) to avoid stale state errors.

---

## Roadmap

### Phase 2 — Data & Persistence
- [ ] Local database (SQLite / Hive)
- [ ] Repository pattern replacing `lib/mock/`
- [ ] Contact import from device phonebook

### Phase 3 — AI Integration
- [ ] Gemini API / Ollama for note processing
- [ ] Automatic summary, task, and reminder extraction
- [ ] Replace simulated `Future.delayed` in `ai_review_screen.dart`

### Phase 4 — Native Android
- [ ] Background call detection service
- [ ] System-wide call overlay
- [ ] Push notification reminders

---

## License

MIT © SmartBroker
