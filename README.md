# Tokipin iOS

Native iOS app for Tokipin (bundle ID `com.tokipin.app`) — leave a small mark (word, emoji, place, time) on the moments you want to remember. SwiftUI, iOS 17+, no account, no network, no location/calendar permissions.

Design source: Figma "Tokipin — Brand · Native App" (pages 02 기록 입력, 03 기록 탐색, 04 제품 기준). Copy and editor rules are shared with the homepage in `../tokipin`.

## Run

Open `Tokipin.xcodeproj` in Xcode 26 and run the `Tokipin` scheme, or:

```sh
xcodebuild -project Tokipin.xcodeproj -scheme Tokipin -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## What's in v0.1

- **First run** opens the editor for today; afterwards the app opens on 기록한 날 (home). Back keeps a draft, `+` continues it; drafts survive app restarts.
- **Editor**: items stack in the order written. Four kind tools (단어 · 이모지 · 장소 · 시간) stay above the keyboard; the emoji tool opens the system emoji keyboard and accepts emoji only; switching kind confirms the current value first. Return confirms one item, ✓ saves everything (including the value being typed). Tap an item to edit it, swipe left to delete (native swipe action), long-press or `…` to multi-select. Deletes can be undone. Save failure keeps the input and offers 다시 시도.
- **Explore**: 일간 (swipe the body for the previous/next day and the week strip for the previous/next week, with a slide animation), 기록한 날 (bento cards, long-press to delete a whole day with undo), 월간 달력 (vertical months, up to three entries + "+N" per day), 연간 (vertical years). Pinch (spread for more detail, pinch for less; UIKit recognizer so it works over scroll views and cards) or the top-right view menu changes level. Pinch is anchored on the date or month between the fingers (thresholds 1.25× in, 0.8× out, same as Android). `오늘` jumps to today.
- **Search**: words, emoji, places, times, kind names ("장소") and dates ("11.25"). Opening a result highlights the item; "검색 결과" goes back to the list.
- **Settings**: touch feedback toggle, JSON export, storage note, privacy policy and terms (pre-launch drafts from the homepage).
- **States**: empty home with the peek rabbit, empty day/month, loading skeleton (only when reading is slow), read-failure recovery with retry.

## Data format

Stored at `Application Support/Tokipin/records.json` (atomic writes); the draft sits next to it in `draft.json`. Export writes the same JSON:

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
- Version 0.1.0; no signing team set.
- Korean only for now (Figma's global date/time formats are not yet applied).

## Localization

Korean is the development language. All user-facing text lives in `Tokipin/Localizable.xcstrings` (String Catalog, source language `ko`). To add a language, add it under Project → Info → Localizations in Xcode and translate the catalog; no code changes are needed.

- SwiftUI `Text("…")`, `Button("…")` etc. are picked up automatically.
- Text built in code uses `String(localized:)`; shared labels use stable keys with a Korean default (`kind.word`, `level.day`, `weekday.sun` …).
- Keep new strings out of plain `String` variables passed to `Text(verbatim:)`, or wrap them in `String(localized:)`.
- Date order (`2026.11.25(수)`) is still fixed in `DayKey`; switch to locale-aware formatting when the first non-Korean language is added.
