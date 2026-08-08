# Gymtracker — Agent Guide

## What this app is

A **simple workout logger**, not an all-in-one fitness platform.

Think notebook or spreadsheet: the user records today's training the way they would on paper or in Excel. Minimal UI, minimal features, no bloat.

## Core features (only these)

1. **Log a workout** — a session for a day (the day's entry). Default home.
2. **Log exercises** inside that workout.
3. **For each exercise: sets, reps, and weight** (unit optional).
4. **Review history** — past sessions by date (default list) and by exercise name (search/filter).

Nothing else unless the user explicitly asks. No social, no meal tracking, no giant exercise encyclopedia, no coaching AI, no charts suite by default.

## Navigation / home

**Home = Log (today’s workout).** Open straight into today’s session. Do not put a chooser hub or two equal “Log / Review” tiles in front of logging.

Two jobs, one shell:

| Tab | Role |
|-----|------|
| **Log** | Today’s notebook entry (create empty session if none). Primary. |
| **History** | Reverse-chronological days + search by exercise name. Secondary. |

Use a **2-item bottom nav** (`Log` | `History`). Avoid dashboards, stats strips, calendar-only homes, or separate top-level “by date” vs “by name” tabs — one history list + one search box covers both.

History behavior:

- Default: list sessions newest-first; one-line preview (exercise names or count).
- Search: filter sessions that contain the typed exercise name (user-grown names only).
- Tap a day → same workout table UI for that session.

## Data model: grow from what the user types

There is **no preloaded mega-database of exercises**.

- The exercise catalog is built **only from names the user has entered**.
- When the user types an exercise in natural language / free text, that name becomes part of their personal list.
- If matching exercises already exist → **autocomplete / suggest** them.
- If none exist → no suggestions; accept the new name and store it for next time.

### Entry shape (spreadsheet-like)

Users enter rows roughly like:

| exercise | reps | weight |
|----------|------|--------|
| bench press flat | 8 | 70 |

- **Weight and reps are required** and repeat as many times as the user wants (one row per set, or equivalent). Weight is how progress is tracked.
- **Units are optional** (kg, lb, etc.). The user may write `70`, `70kg`, `70lb`, or omit the unit. Do not force a unit picker or normalize aggressively unless asked.
- Parsing should tolerate casual text input; prefer forgiving over rigid schemas.

Example mental model of a line:

```
bench press flat | 8 | 70
```

## Product principles for agents

- **YAGNI.** If it isn't logging workouts / exercises / sets-reps-weight, question it.
- **Notebook UX over app UX.** Feel closer to a notepad or Excel sheet than to a gym SaaS.
- **User-grown data.** Catalog = history of what they typed, not a seed dump.
- **Autocomplete only when there is something to suggest.** Empty catalog → no fake suggestions.
- **Shortest working change.** Prefer reusing existing Flutter/Dart patterns in this repo over new layers, packages, or abstractions.
- **Fewest files.** Boring over clever.

## Stack

Flutter app (`pubspec.yaml` name: `gymtracker`). Prefer platform/stdlib and already-installed deps before adding packages.

## Architecture (`lib/`)

Feature-first layout. Put code in the matching feature; shared only when two+ features need it. Do not invent extra layers beyond this tree.

```
lib/
│
├── core/
│   ├── database/
│   │   ├── app_database.dart
│   │   └── migrations.dart
│   │
│   ├── services/
│   │   ├── ai_service.dart
│   │   └── logger.dart
│   │
│   ├── theme/
│   └── utils/
│
├── features/
│   │
│   ├── home/
│   │   └── screens/
│   │
│   ├── workouts/
│   │   ├── models/
│   │   ├── repository/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── widgets/
│   │
│   ├── exercises/
│   │
│   ├── history/
│   │   └── screens/
│   │
│   └── settings/
│
├── shared/
│   ├── widgets/
│   ├── extensions/
│   └── constants/
│
└── main.dart
```

### Layout rules

- **`core/`** — app-wide infrastructure: DB, services, theme, utils. Not feature UI.
- **`features/`** — one folder per product area. Mirror `workouts/` internals (`models/`, `repository/`, `providers/`, `screens/`, `widgets/`) when a feature needs them; skip empty folders.
- **`shared/`** — cross-feature widgets, extensions, constants only.
- **`main.dart`** — app entry / wiring only.

## Out of scope (unless explicitly requested)

- Pre-seeded global exercise databases
- Complex periodization / program builders
- Nutrition, bodyweight graphs, wearables, social, cloud sync as defaults
- Heavy onboarding or multi-step wizards for basic logging
- Dashboard / marketing-style home with action tiles instead of Log-first
