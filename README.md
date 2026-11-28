# Tokipin iOS

Native iOS app for Tokipin (bundle ID `com.tokipin.app`) — leave a small mark (word, emoji, place, time) on the moments you want to remember. SwiftUI, iOS 18+, offline journal, optional usage analytics, no account or location/calendar permissions.

Design source: Figma "Tokipin — Brand · Native App" (pages 02 기록 입력, 03 기록 탐색, 04 제품 기준). Copy and editor rules are shared with the homepage in `../tokipin`.

## Run

Open `Tokipin.xcodeproj` in Xcode 26 and run the `Tokipin` scheme, or:

```sh
xcodebuild -project Tokipin.xcodeproj -scheme Tokipin -destination 'platform=iOS Simulator,name=iPhone 17' test
```

`WindowChangeTests` (UX v0.4 §5: window size changes keep the editor, search and scroll state)
runs on iPad only and is skipped on iPhone, so run the suite on an iPad simulator too:

```sh
xcodebuild -project Tokipin.xcodeproj -scheme Tokipin -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test
```

The signed/release app uses the **tokipin-app** Firebase project's Apple configuration for
`com.tokipin.app`. Put the downloaded `GoogleService-Info.plist` under `Tokipin/`
before building Release. The config stays outside version control. Debug builds without
it keep all journal features available and leave usage sharing disabled.

New users can choose optional usage sharing when they finish the sample journal and start their own. Existing users keep their single invitation on the normal launch path. Settings can change it
at any time. Firebase starts only after opt-in. Analytics collects app activity and a
parameterless `record_saved` after an explicit changed, non-empty save succeeds. Entries,
dates, searches, drafts, deletion, undo and sample data are excluded from custom events.

## What's in v0.1

- **First run** opens the real editor in a private sample journal with three years of localized entries. Follow the gestures or tap Next to explore the four calendar views. Start at the final invitation opens today's blank personal editor. Sample edits stay in memory. Returning users open their existing draft or 기록한 날 (home).
- **Editor**: items stack in the order written. Four kind tools (단어 · 이모지 · 장소 · 시간) stay above the keyboard; the emoji tool opens the system emoji keyboard and accepts emoji only; switching kind confirms the current value first. Return confirms one item, ✓ saves everything (including the value being typed). Tap an item to edit it, swipe left to delete (native swipe action), long-press or `…` to multi-select. Deletes can be undone. Save failure keeps the input and offers 다시 시도.
- **Explore**: 일간 (swipe the body for the previous/next day and the week strip for the previous/next week, with a slide animation), 기록한 날 (bento cards, long-press to delete a whole day with undo), 월간 달력 (vertical months, up to three entries + "+N" per day), 연간 (vertical years). Pinch (spread for more detail, pinch for less; UIKit recognizer so it works over scroll views and cards) or the top-right view menu changes level. Pinch is anchored on the date or month between the fingers (thresholds 1.25× in, 0.8× out, same as Android). `오늘` jumps to today.
- **Search**: words, emoji, places, times, kind names ("장소") and dates ("11.25"). Opening a result highlights the item; "검색 결과" goes back to the list.
- **Settings**: 진동 (haptics) and optional usage-sharing toggles, JSON export, storage note, offline privacy policy and terms from the website.
- **States**: empty home with the peek rabbit, empty day/month, loading skeleton (only when reading is slow), read-failure recovery with retry.

## Native UX v0.2 (shared with Android)

Gesture, haptic, calendar, time and emoji behaviour follows "Tokipin Native UX v0.2" (v0.1 plus
기록한 날 month paging). The spec has one copy for both apps, outside this repo, at
`../tokipin/native-spec/v0.2/` (`Tokipin-Native-UX-v0.2.md` + `.json`, SHA-256 `418fbe56…05ea9`).
`TokipinTests/NativeUXSpecTests.swift` reads the JSON from that sibling path, checks the pin, and runs
every case that applies to iOS (81 of 82; `emoji.externalIme` is Android-only), including the 23
`recordedMonths` cases. Clone the web repo next to this one to run the tests.

- 기록한 날: one month per page (`RecordsView`), body swipe ±1 month with the day pager's thresholds,
  a centred month rail (`MonthRail`) with native fling + snap, one tick per committed different month
  (`AppModel.commitRecordsMonth`).

- Product rules and thresholds: `Tokipin/Core/InteractionRules.swift` (swipe 0.22W / flick 0.06W + 0.9W/s,
  axis lock 1.3, pinch 1.25 / 0.80, settle 200ms / cancel 150ms / reduce motion 80ms, haptic events).
- Emoji and time rules: `Tokipin/Core/EmojiRules.swift`. Native adapters: `Haptics`, `PinchCatcher`,
  `ComposerField`, `SwipePager`.
- All navigation (tap, swipe, pinch, view menu) goes through `AppModel.navigate`, which requests at most one tick.

## Daily read & edit

- **Empty day**: a small glass card with the peeking rabbit under the date strip, `+` opens that day's editor. The empty text is VoiceOver-only ("이날 남긴 기록이 없어요.").
- **Empty 기록한 날 month**: the same art inside the month page (it travels with the swipe and comes back on cancel); VoiceOver announces "<month>에 남긴 기록이 없어요." once when the month settles.
- **Art layout** (`EmptyRecordArt`): 172×120 at 390pt width (rabbit 90×90), width = round(44% of page width) capped at 172, ratio kept; horizontally centred; its centre sits at 30% of the height between the strip/rail and the bottom buttons, clamped on short screens.
- **Filled day**: read-only items, one pencil (이날 기록 편집) at the bottom. The pencil opens the editor with the keyboard closed; tapping an item edits it with its own tool.
- **Editor**: long press and release in place → 삭제 menu; long press and drag up/down → reorder across kinds; swipe to delete with undo. VoiceOver actions: 위로 이동, 아래로 이동, 삭제.
- Changes are saved only with ✓. The first saved item replaces the rabbit; saving with the last item deleted returns to the same day's empty screen. Drafts are kept per day.

## Native UX v0.3 (date headers, 기록한 날 months)

- These rules are unchanged in v0.4; the 109 cases run from the v0.4 file (below).
- Header titles sit on the screen's centre line: 일간 "2017.05" (selected day), 기록한 날 the committed month's year, 월간 the visible month's year, 연간 none (each block carries its year), editor "2017.05.14 ⌄".
- 기록한 날 pages = months with saved items + this month (`RecordedMonths`). Body swipe, rail, taps, flings and VoiceOver all step through that list; past either end is empty. When the committed month disappears (delete, import, month change) the nearest shown month opens, the more recent on a tie, silently.
- The rail reserves a hint line: for each other year, the slot nearest the centre shows its 4-digit year.

## Native UX v0.4 (wide and folding screens)

- Shared spec: `../tokipin/native-spec/v0.4/Tokipin-Native-UX-v0.4.json` (194 cases, SHA-256 81a9e6fd…7203). `NativeUXSpecTests` runs the 109 kept from v0.3, `AdaptiveSpecTests` the 85 new ones against `Core/AdaptiveLayout.swift` (a port of `adaptive-layout.cjs`). Set `TEST_RUNNER_TOKIPIN_SPEC_DIR=<folder>` to read another checkout of the folder.
- One column is capped at 640pt and centred. A window at least 600×480 shows two panes (`Features/Root/PaneContainer.swift`): the calendar (the level it shows, search list, views, 오늘) on the left and the selected day (더보기, pencil or +) on the right, each at most 640pt against the split. An empty journal and the sample tour stay in one column.
- The editor is a layer of the container (not a full-screen cover): in two panes it takes the day pane and dims the calendar; a window change only moves its frame, so text, caret and keyboard stay.
- Folds (iOS 27.1 `reservedRegions(kind: .division)`) are not read yet: this build uses the iOS 26 SDK.

## Calendar range

- The device's local month is the last month; new records can go up to its last day. Explore starts at the earlier of 11 months ago and the oldest saved record's month (recent 12 months with no records). Only saved records move the range; drafts and the picker never do.
- **월간**: stops at the first month. Before the protected recent 12 months, a run of ≥ 6 empty months folds into one row ("2017.06 – 2023.03"); 1–5 stay open. Tap the row to open or fold it; entering a folded month from elsewhere opens it.
- **연간**: years that overlap the recent 12 months or hold a record stay open; record-less past years in between fold into one row. Months outside the range are dimmed and inactive. The selected month's focus, per-day record dots and the year/month summary dots are all shown together.
- **기록한 날**: month paging and the rail stay inside the range (empty months included).
- **Editor date**: tap the centre date. ✕ restores everything; ✓ moves the editor only (the editor's ✓ saves). New pieces travel to the chosen day after its own items, once; a saved day opened with the pencil keeps its changes there as a draft.
- Rules live in `CalendarRange` and `EntryDateChange` (tested with the shared fixture, reference date 2026-11-26).

## Sample data (debug builds)

- **달력 범위 예시 넣기** (Settings → 개발용 테스트 데이터) loads `Tokipin/DebugFixtures/calendar-range-records.json` (512 days, 1,632 items, SHA-256 530bfab8…8744, shared with web and Android). It replaces records and drafts; use it on a clean test install. The file is excluded from Release builds.

Settings › 개발용 테스트 데이터 (Debug only) → 예시 기록 넣기 fills the app with the same records as
the homepage trial: `Tokipin/Core/SampleGenerator.swift` is a port of `../tokipin/trial.js` +
`trial-content.js` (same seeded generator, 28 themes, Korean words, three years ending today, quiet
days left empty). `SampleRecordsTests` runs the web scripts in JavaScriptCore and checks every
day and item match. 모든 기록 지우기 clears everything for the empty home.

## Data format

Stored at `Application Support/Tokipin/records.json` (atomic writes); unsaved drafts sit next to it in `drafts.json`, one per day (a v0.1 `draft.json` is migrated on load). Export writes the same JSON:

```json
{
  "version": 1,
  "days": [
    {
      "date": "2026-11-25",
      "updatedAt": "2026-11-25T10:00:00Z",
      "items": [
        { "id": "UUID", "kind": "word", "value": "살구잼" },
        { "id": "UUID", "kind": "place", "value": "연남동" },
        { "id": "UUID", "kind": "time", "value": "16:20" },
        { "id": "UUID", "kind": "emoji", "value": "🍊" }
      ]
    }
  ]
}
```

`kind` is one of `word`, `emoji`, `place`, `time`; times are `HH:mm` (24h). Keep this identical on Android so exports are interchangeable.

## Brand

Palette 세이지 차콜: Canvas `#39453D`, Surface `#252C29`, Primary `#F3F3EC`, Secondary `#C3CDC5`, Focus `#BBD2F2`. Fonts: DM Sans (numbers/Latin) with Noto Sans KR fallback for Hangul, bundled as variable TTFs (SIL OFL). Icons and the peek rabbit come from the homepage assets.

## Open questions / guesses

- Background gradient colors, card sizes and the view-menu icons were sampled by eye from Figma screenshots.
- The time tool uses an inline 24-hour wheel with a "시간 추가" button.
- Version 0.1.0; signed with the personal developer team (Hyeonwoo Cho, 9QA57R9ZML).
- Korean only for now (Figma's global date/time formats are not yet applied).

## Localization

Korean is the development language. All user-facing text lives in `Tokipin/Localizable.xcstrings` (String Catalog, source language `ko`). To add a language, add it under Project → Info → Localizations in Xcode and translate the catalog; no code changes are needed.

- SwiftUI `Text("…")`, `Button("…")` etc. are picked up automatically.
- Text built in code uses `String(localized:)`; shared labels use stable keys with a Korean default (`kind.word`, `level.day`, `weekday.sun` …).
- Keep new strings out of plain `String` variables passed to `Text(verbatim:)`, or wrap them in `String(localized:)`.
- Date order (`2026.11.25(수)`) is still fixed in `DayKey`; switch to locale-aware formatting when the first non-Korean language is added.
