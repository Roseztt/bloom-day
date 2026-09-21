# Bloom Day

A soft, encouraging iOS task app: write down what you need to do and when it's due, get nudged until it's done, and watch your progress grow.

Built with SwiftUI and SwiftData. Everything stays on the device — no account, no server, no API keys. The only network access is the Feed tab fetching public RSS.

**Requires iOS 17+** (iPhone and iPad). A couple of features need newer OS versions — see [Notes](#notes).

## Features

**Tasks** — deadlines, priorities, categories (School / Personal / Work), rough durations, and a checklist of steps inside each one. Ticking the last step completes the task; un-ticking one reopens it.

**Reminders** — a heads-up before the deadline, a nudge at the deadline, then follow-ups until it's done. Notifications carry **Mark Done** and **Snooze** actions. Plus a daily summary and quiet hours.

**Apple Calendar** — your events appear alongside your tasks, read-only, in their real calendar colours. Import any of them as a proper task with one tap.

**Feed** — a full-screen, one-story-per-swipe news reader over plain RSS. Pick topics or add your own feed URL; it remembers what you've read so the same stories don't come back.

**Describe it** — write "make a cake next week, need flour and to watch a baking video" and get a task with steps back, using Apple's on-device model. Nothing is saved until you approve the preview.

**Progress** — completion ring, day streak, weekly chart, monthly breakdown, focus hours, achievements, and a productivity level. All computed from real task history.

## The tabs

| Tab | Contents |
| --- | --- |
| Home | Calendar, today's progress, today's plan, calendar events |
| Tasks | Category filters, search, Today / Upcoming / Completed |
| Feed | Swipe-up news reader |
| Progress | Stats and charts |
| Profile | Goals, stats, settings |

There's no Calendar tab — the card on Home expands from a week row to a full month grid. iPhone only shows five tabs before iOS collapses the rest into a "More" list.

## Running it

Xcode 16+ and a Mac. To run in the Simulator, just open and build:

```bash
open Tracker.xcodeproj
```

To install on a real iPhone you need a cable and an Apple ID (a free one works):

1. On the phone: **Settings → Privacy & Security → Developer Mode** → on, then restart.
2. In Xcode: **Settings → Accounts → +** → sign in.
3. Select the **Tracker** target → **Signing & Capabilities** → set **Team**.
4. Plug in the phone, pick it from the device menu, press **⌘R**.
5. On the phone: **Settings → General → VPN & Device Management** → trust the developer.
6. Allow notifications on first launch, or nothing will remind you.

Command-line build:

```bash
xcodebuild -project Tracker.xcodeproj -scheme Tracker \
  -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

## Project structure

All source is in `Tracker/`.

| Area | Files |
| --- | --- |
| Models | `TaskItem`, `TaskStep`, `TaskCategory`, `Goal`, `ProductivityLevel` |
| Data | `DataController`, `TaskActions`, `SettingsStore` |
| Notifications | `NotificationManager`, `AppDelegate` |
| Screens | `HomeView`, `TasksView`, `FeedView`, `ProgressDashboardView`, `ProfileView` |
| Components | `Theme`, `BloomHeader`, `BunnyMascot`, `TaskCard`, `CalendarCard` |
| Calendar | `CalendarBridge`, `CalendarViews` |
| Feed | `FeedTopic`, `FeedParser`, `FeedStore`, `FeedSettingsView` |
| Planner | `TaskPlanner`, `HeuristicPlanner`, `PlanWithAIView` |
| Debug only | `DemoData`, `DemoCalendar` (both `#if DEBUG`) |

## Notes

**Liquid Glass** — the tab bar is a plain `TabView` on purpose. iOS 26 gives it the floating glass treatment for free; a custom tab bar or any `UITabBar.appearance()` override would lose it.

**Notification budget** — iOS caps an app at 64 pending local notifications. The schedule is rebuilt from scratch on every change, keeping the soonest ~56. Calendar events are capped at 12 and all-day entries skipped so they can't crowd out task reminders.

**On-device AI** — "Describe it" uses the Foundation Models framework, which needs iOS 26 and Apple Intelligence enabled. It doesn't run in the Simulator. Everywhere else it falls back to a text parser (`HeuristicPlanner`), and the UI says which one produced the result.

**Free-account signing** — builds signed with a free Apple ID stop launching after 7 days. Plug in and ⌘R to reset; your data is untouched. Don't change the bundle identifier — iOS would treat it as a new app with an empty database.

**Demo data** — launch with `-seedDemoData YES` to populate the app, and `-startTab N` to open on a given tab. `-seedDemoEvents YES` adds events to a dedicated "Bloom Day Demo" calendar, never your real ones. All compiled out of Release builds.

## Artwork

The bunny and app icon are bundled image assets. Replace the icon with a 1024×1024 PNG (no alpha) at `Tracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. The mascot poses live as `Bunny-<name>` image sets and are listed in `BunnyPose`.
