# Bloom Day

A soft, encouraging iOS task app: write down what you need to do and when it's due, get nudged until it's done, and watch your progress grow.

**Runs on iOS 17.0 and later, iPhone and iPad.** That covers every iPhone from the 8 / SE 2 onward, so an iPhone 16 Pro Max and anything newer is well inside the range. The layout is adaptive, so it fits every screen from SE to Pro Max to iPad.

Your tasks, goals and calendar stay entirely on the device — no account, no server, nothing synced anywhere. The only network access is the Feed tab fetching public RSS.

## The five tabs

| Tab | What's there |
| --- | --- |
| **Home** | Greeting, the bunny, the calendar, today's completion ring, today's plan, and your calendar events |
| **Tasks** | Category filters, search, and Today / Upcoming / No deadline / Completed sections |
| **Feed** | Full-screen, swipe-up news from the topics you pick |
| **Progress** | Today's ring, day streak, weekly completion chart, this month's breakdown, focus hours, achievements |
| **Profile** | Your name and line, productivity level, stats, goals, and settings |

There's no separate Calendar tab: the card on Home starts as a single week and expands to the full month grid with the category legend when you tap **Show month**. iPhone only shows five tabs before iOS pushes the rest into a "More" list, which would have broken the Liquid Glass bar.

## Feed

A vertical, one-story-per-swipe reader. Each story fills the screen — artwork behind, headline and summary over a gradient scrim, and a **Read the story** button that opens an in-app Safari view with Reader mode on.

- **Topics** in Profile → News Feed (or the slider icon on the Feed itself): Top stories, World, Science, Technology, Health, Business, Education. You can paste your own RSS or Atom URL too.
- **Plain RSS, no API key.** Nothing to sign up for, nothing that can start charging or get revoked. Fetched straight from BBC, NPR and Ars Technica.
- **Several publishers per topic** (3–5 each: BBC, NPR, Guardian, Ars Technica, The Verge, Al Jazeera, Sky, Phys.org, Hacker News). One feed only carries its last ~20–40 stories, so a single source runs dry and starts repeating. Two topics selected gives roughly 200 stories.
- **It remembers what you've read.** Story ids are recorded as each card comes on screen and filtered out of later fetches, so you don't open it tomorrow to yesterday's headlines. Capped at 1,500 ids and expired after 45 days, so stories can eventually resurface. "Clear read history" in feed settings resets it.
- **Reaching the bottom fetches more** rather than dead-ending, appending anything new. When there genuinely isn't any, you get an end card offering a recheck, a jump back to the top, and the option to see stories you've already read.
- Feeds are fetched **in parallel** and **round-robined**, so one prolific source can't monopolise the top of the scroll. Results are cached to disk, so the feed still has something to show offline, and refetched when older than 15 minutes or on pull-to-refresh.

The parser handles the messiness of real feeds: it prefers whichever of `description` / `content:encoded` is meatier, de-duplicates sentences that some publishers repeat in both, and finds artwork from `media:thumbnail`, `media:content`, `enclosure`, or an `<img>` embedded in the HTML body.

## Describe it (on-device AI)

Tap the ✨ button on Home or **Describe it** on Tasks, write what you're trying to do in plain words, and you get a task with steps back:

> *"I want to make a cake next week I need to buy flour and learn baking video"*
> → **Make a cake**, Personal, due next week 6pm, steps: *Buy flour*, *Learn baking video*

Nothing is saved until you've seen it. The preview is fully editable — retitle it, change the category or date, delete steps — and only **Add** commits it.

**It runs on your phone.** Apple's on-device Foundation Models framework, so there's no API key, no server, no per-request cost, and your notes never leave the device. Needs iOS 26 and Apple Intelligence switched on.

**When that isn't available** — older iOS, an ineligible device, Apple Intelligence off, or the Simulator — it falls back to a plain-language parser in `HeuristicPlanner.swift` that handles lead-ins ("I want to…"), joiners ("and", "then", "I need to"), timing ("next week", "Friday", "in 3 days") and category keywords. Dumber, but the feature still works. The preview always states which one produced the result, so a silent model failure can't pass itself off as AI.

## Steps within a task

Tap any task to open it. Underneath its details is a checklist you can break the work into:

- Type in **Add a step** and hit return; the field keeps focus so you can rattle off several in a row.
- Tick steps as you go. Swipe a step to delete it, or use **Edit** to drag them into a different order.
- The task's own card shows a slim bar and `2/5` wherever it appears — Home and Tasks.

**Ticking the last step marks the whole task done, and un-ticking one reopens it.** That's deliberate: a half-finished checklist on a "completed" task would be a contradiction, and it saves ticking the same thing twice.

## Apple Calendar

Your events show up next to your tasks, read-only — Bloom Day never writes to your calendar.

- **Alongside, not merged.** Events appear in their own section on Home, under the day you've selected, in their real calendar colours, with location and time. They have no checkbox, because a lecture isn't something you complete.
- **Import the ones you want.** Every event row has a **+**, and there's an *Import from Calendar* picker on Home for bulk selection. Importing makes a real task with reminders and a checkbox, and the original stops showing separately (matched on the event id, so it can't double up).
- **Reminders for events** are on by default — one heads-up, 15 minutes before, configurable in Reminder Settings.

Two deliberate limits on event reminders: **all-day entries are skipped** (a notification for a public holiday is noise), and events are **capped at 12 pending**. Both exist so a calendar full of birthdays and holidays can't eat the 64-notification budget your actual task reminders depend on.

## Reminders

- A heads-up before the deadline, a nudge at the deadline, then follow-ups every few hours until you check it off.
- The notification itself has **Mark Done** and **Snooze** buttons, so you can clear things from the lock screen.
- One daily summary each morning with what's overdue and what's due today.
- **Quiet hours** hold anything that would fire overnight until the morning.

All of it is tunable in Profile → Reminder Settings.

## Things that are real, not decorative

Every number in the app is computed from your actual task history:

- **Streak** — consecutive days with at least one completion. Today not being started yet won't break a run built through yesterday.
- **Productivity level** — a ladder (Seedling → Sprout → Budding → Bright Bloomer → In Full Bloom → Radiant) driven by lifetime completions.
- **Focus hours** — the sum of the rough durations you set, over tasks you actually finished.
- **Achievements** — recomputed from the history each time, so they can never get out of step.
- **Weekly completion** — the share of each day's due tasks that got done.

## Design notes

- **Liquid Glass**: the tab bar is a plain SwiftUI `TabView` on purpose. On iOS 26 the system gives it the floating glass treatment and the scroll-away animation for free — a custom tab bar or any `UITabBar.appearance()` override would throw that away.
- **The bunny** comes from your sticker sheet. All 24 poses were cut out of it, tile backgrounds removed, and live in the asset catalog as `Bunny-<name>`. `BunnyPose` in `BunnyMascot.swift` lists them; swapping a screen's mascot is a one-word change.
- **Type** is SF Rounded throughout — the soft feel without bundling a font.
- **Dark mode** is supported: every colour in `Theme.swift` carries a dark counterpart so the pastels don't glow at night. Profile → Themes & Appearance can pin it light or dark.

### Artwork

The app icon is your bunny-with-calendar illustration, cropped inside its own rounded corners so it bleeds edge to edge (iOS applies its own mask, so a baked-in rounded card would read as an inset tile) and flattened to remove transparency. To replace it, drop a 1024×1024 PNG with no alpha at `Tracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

Which pose appears where:

| Screen | Pose |
| --- | --- |
| Home header | `home`, or `completed` once the day is cleared |
| Calendar card on Home | `calendar` |
| Tasks header | `todo` |
| Progress header | `progress` |
| Profile header / avatar / footer | `favorites` / `selfCare` / `coffeeBreak` |
| Empty states | `sleep`, `addTask`, `plan` |

The other 15 poses (`focus`, `study`, `goals`, `ideas`, `nightMode`, …) are bundled and ready to use.

## Getting it onto your iPhone

You need the Mac and the phone connected by cable for the first install.

1. **Enable Developer Mode on the iPhone** (one time)
   Settings → Privacy & Security → Developer Mode → on, then restart the phone.

2. **Add your Apple ID to Xcode** (one time)
   Xcode → Settings → Accounts → **+** → Apple ID. A free account is fine.

3. **Open the project**

   ```bash
   open Tracker.xcodeproj
   ```

4. **Set signing**
   Select the **Tracker** target → **Signing & Capabilities** tab.
   - Check *Automatically manage signing*
   - **Team**: pick your Apple ID
   - **Bundle Identifier**: already set to `com.rosezhao.bloomday2026`. Keep it — changing it makes iOS treat this as a brand-new app with an empty database.

5. **Run it**
   Plug in the iPhone, unlock it, tap *Trust* if asked. Pick your phone from the device menu at the top of the Xcode window, then press ⌘R.

6. **Trust the app on the phone** (first install only)
   Settings → General → VPN & Device Management → tap your Apple ID → Trust.

7. **Allow notifications** when the app asks on first launch. Without this, nothing will remind you.

### The 7-day catch

Apps signed with a *free* Apple ID stop launching after 7 days. To reset the clock, plug the phone in and press ⌘R again — your tasks are untouched. A paid Apple Developer account ($99/yr) raises this to a year.

## Notes on how reminders work

- iOS caps an app at 64 pending local notifications. The app rebuilds the whole schedule whenever something changes, keeping the soonest ~56 and refilling as they fire. If you have a lot of tasks far out, the distant ones get scheduled later rather than never.
- The daily summary's text is written when it's scheduled, so it reflects your list as of the last time you opened or backgrounded the app.
- Overdue and high-priority reminders are marked *time-sensitive*, which lets them break through a Focus mode. That only takes effect if the app is signed with the Time Sensitive Notifications capability — with a free account it quietly falls back to normal delivery.
- Quiet hours push a reminder to the moment the window ends. Two things buried at 3am both surface at 8am.

## Building from the command line

```bash
xcodebuild -project Tracker.xcodeproj -scheme Tracker -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

## Demo data

`DemoData.swift` fills the app with a realistic week of tasks and goals for screenshots and poking at the UI. It's wrapped in `#if DEBUG`, so it's compiled out of Release builds entirely and never reaches the phone when you archive.

```bash
xcrun simctl launch "iPhone 18 Pro Max" com.rosezhao.bloomday2026 -seedDemoData YES -startTab 1
```

`-startTab` picks the opening tab (0 Home, 1 Calendar, 2 Tasks, 3 Progress, 4 Profile). Seeding only runs when the task list is empty — `xcrun simctl uninstall` first to start over.

`-seedDemoEvents YES` additionally puts a few events into a dedicated **"Bloom Day Demo"** calendar so the Apple Calendar integration can be exercised. It's guarded three ways: compiled out of Release, only runs with that launch argument, and only ever writes to its own calendar — never your real ones. Neither flag is passed by a normal ⌘R from Xcode.

## Layout

| File | What it does |
| --- | --- |
| `Theme.swift` | Palette (light + dark), type scale, card and pill styles |
| `BunnyMascot.swift` | The vector bunny, speech bubble and sprig |
| `BloomHeader.swift` | Shared screen header and the rotating encouragements |
| `TaskItem.swift` / `TaskCategory.swift` | The task model and its category / status types |
| `TaskStep.swift` | A single checklist step, cascade-deleted with its task |
| `TaskDetailView.swift` | What opens when you tap a task: details plus the checklist |
| `CalendarBridge.swift` / `CalendarViews.swift` | Read-only EventKit access, event rows, import picker |
| `CalendarCard.swift` | The week/month picker on Home |
| `TaskPlanner.swift` / `HeuristicPlanner.swift` | On-device planning, and the fallback parser |
| `PlanWithAIView.swift` | The "describe it" sheet and editable preview |
| `FeedTopic.swift` / `FeedParser.swift` / `FeedStore.swift` | RSS topics, XML parsing, fetching and caching |
| `FeedView.swift` / `FeedSettingsView.swift` | The swipe reader and its topic picker |
| `Goal.swift` | Longer-running goals shown on Profile |
| `ProductivityLevel.swift` | Level ladder and achievement evaluation |
| `DataController.swift` | Owns the store so the notification handler can reach it |
| `NotificationManager.swift` | Builds and installs the entire reminder schedule |
| `SettingsStore.swift` | Preferences, quiet-hours maths, appearance |
| `AppDelegate.swift` | Handles notification taps and the Done / Snooze buttons |
| `HomeView` / `TasksView` / `FeedView` / `ProgressDashboardView` / `ProfileView` | The five tabs |
| `TaskCard.swift` / `WeekStrip.swift` | Shared components |
| `TaskEditorView.swift` / `ProfileSubviews.swift` / `ReminderSettingsView.swift` | Editors and settings screens |
