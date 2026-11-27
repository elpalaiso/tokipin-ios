# Localization (iOS)

17 languages, matching the web (`tokipin@9e512c1/locales`): ko (source), en, ja, de, fr, id, vi, tr, ru, hi, th,
pt-BR, es (Spain), es-419, zh-Hans, zh-Hant (Taiwan), zh-HK. Web codes map to Apple identifiers as
es-ES → `es`, zh-Hant-TW → `zh-Hant`, zh-Hant-HK → `zh-HK`.

- The app follows the device language (or the per-app language in iOS Settings). A language the app
  does not support falls back to English (`developmentRegion = en`); the main interface catalog uses Korean source keys.
- Strings live in `Tokipin/Localizable.xcstrings` (source language ko). Rows follow the Figma
  [iOS handoff table](https://www.figma.com/design/DCXIvwQgfRlhz65FdjZJ5n/Tokipin?node-id=311-1097):
  그대로 = web dictionary value, 조정 = web term adapted to iOS arguments, 별도 = iOS-only translation.
- The offline policy screens use the English HTML articles as their source and the site dictionaries for all 17 languages.
  The generator uses the `data-site-text` attributes to match the translations. After editing the web policies, run
  `TOKIPIN_WEB_LOCALES=../tokipin/locales python3 tools/l10n/build_catalog.py`. Check in `Tokipin/Policies.xcstrings` and the generated Swift document.
- Dates, months and years come from `DateFormatter` templates in the app language (`DayKey.label`,
  `MonthKey.spokenLabel`, `MonthKey.monthName`, `MonthKey.spokenYear`). Header numbers keep the fixed
  YYYY.MM.DD / YYYY.MM / YYYY notation. Weekday keys use each locale's short standalone names.
- Counts use plural variations (one/few/many/other per language); sentences with other arguments use a
  `%#@count@` substitution so the argument order can change per language.
- DEBUG-only test-data strings (TP-0258…TP-0296) are not in the catalog.
- `LocalizationTests` reads every compiled `.lproj`: all languages ship, plurals at 0/1/2/5/21, argument
  order, regional variants and the vibration wording.

## Change log (since the 2026.11.27 handoff, iOS 2f330a4)

| Date · ID · screen | Before → after · reason | Locales · variables | iOS status |
|---|---|---|---|
| 2026.11.27 · TP-0198 · editor field (VoiceOver) | `%@ 입력` → four phrases `단어 입력`, `이모지 입력`, `장소 입력`, `시간 입력` (web TP-0108…0111) · word order differs by language | 16 · none | applied |
| 2026.11.27 · TP-0206 · 연간 month (VoiceOver) | `%lld월, 기록한 날 %lld일` → `%@, 기록한 날 %lld일` · month from the locale formatter, count plural | 16 · month name, count | applied |
| 2026.11.27 · TP-0257 · 연간 month out of range | `%lld월, 범위 밖` → `%@, 범위 밖` | 16 · month name | applied |
| 2026.11.27 · TP-0249…0251 · 연간 folded years / year title | `%@년…` → `%@, 기록 없는 해`, `%@부터 %@까지 기록 없는 %lld년`, `%@, 기록 있음` · year from the formatter, count plural | 16 · year, count | applied |
| 2026.11.27 · TP-0252 · 월간 folded months | same key, count now plural | 16 · months, count | applied |
| 2026.11.27 · TP-0205, TP-0247, TP-0248, TP-0256 · month/year names | `%lld년 %lld월`, `%@년`, `%@년 %lld월`, `%lld월` → removed; locale `DateFormatter` | — | applied |
| 2026.11.27 · TP-0244, TP-0246 · full date | `%@(%@)` → Korean unchanged, other languages `yMMMdEEE` formatter | — | applied |
| 2026.11.27 · TP-0283 · date picker year chip | `연도 %@` argument is the formatted year | 16 · year | applied |
| 2026.11.27 · TP-0231, TP-0232, TP-0204 · counts | plural variations added | 16 · count | applied |
| 2026.11.27 · TP-0239 · settings export | web "download" → iOS "save as a JSON file" (system file exporter) | 16 | applied |
| 2026.11.27 · TP-0197, 0199, 0202, 0203, 0215, 0222, 0226, 0233, 0235 | no call site in the app → removed from the catalog | — | closed |
| 2026.11.27 · TP-0207 · `level.year` | Korean keeps `연간`; other languages use web TP-0050 (Year calendar) until the menu name is agreed | 16 | pending agreement |

Translations marked 별도/조정 are drafts by the implementer; language review is pending.
