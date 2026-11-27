"""Builds Tokipin/Localizable.xcstrings for 17 languages.

Sources, in order:
  1. Web dictionaries at tokipin@9e512c1 (locales/demo, locales/site), matched by the Korean key (그대로).
  2. Web templates adapted to iOS arguments (조정): {month}/{view}/{count} → %@/%lld.
  3. native_tr.py: iOS-only sentences (별도) and iOS overrides of adjusted rows.
  4. Locale weekday symbols for weekday.* keys (Foundation, per locale).
"""
import glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from native_tr import T as NATIVE, LANGS

WEB = os.environ.get('TOKIPIN_WEB_LOCALES') or os.path.join(os.path.dirname(__file__), '../../../tokipin/locales')
HERE = os.path.dirname(__file__)
OUT = os.path.join(os.path.dirname(__file__), '../../Tokipin/Localizable.xcstrings')

APPLE = {"en": "en", "ja": "ja", "de": "de", "fr": "fr", "id": "id", "vi": "vi", "tr": "tr", "ru": "ru", "hi": "hi",
         "th": "th", "pt-BR": "pt-BR", "es-ES": "es", "es-419": "es-419", "zh-Hans": "zh-Hans",
         "zh-Hant-TW": "zh-Hant", "zh-Hant-HK": "zh-HK"}

demo = {os.path.basename(f)[:-5]: json.load(open(f)) for f in glob.glob(WEB + '/demo/*.json')}
site = {os.path.basename(f)[:-5]: json.load(open(f)) for f in glob.glob(WEB + '/site/*.json')}
weekdays = json.load(open(os.path.join(HERE, 'weekdays.json')))
NATIVE.update(json.load(open(os.path.join(HERE, 'onboarding.json'))))
keys = json.load(open(os.path.join(HERE, 'keys.json')))

def web(lang, key):
    if key in demo.get(lang, {}): return demo[lang][key]
    if key in site.get(lang, {}): return site[lang][key]
    return None

def convert(value, mapping):
    """Replace web {placeholders} with iOS format specifiers."""
    if isinstance(value, dict):
        return {k: convert(v, mapping) for k, v in value.items()}
    for name, spec in mapping.items():
        value = value.replace('{' + name + '}', spec)
    return value

# Adjusted rows: iOS key -> (web key, placeholder mapping) or a function(lang) -> value.
VIEW_BACK = {"연간 달력으로": "연간 달력", "월간 달력으로": "월간 달력", "기록한 날로": "기록한 날", "일간으로": "일간"}
DERIVED = {
    "kind.word": ("단어", {}), "kind.emoji": ("이모지", {}), "kind.place": ("장소", {}), "kind.time": ("시간", {}),
    "level.day": ("일간", {}), "level.records": ("기록한 날", {}), "level.month": ("월간 달력", {}),
    "level.year": ("연간 달력", {}),           # TP-0207: Korean menu keeps the short '연간'
    "탐색 보기, %@": ("탐색 보기, {view}", {"view": "%@"}),
    "%@에 남긴 기록이 없어요.": ("{month}에 남긴 기록이 없어요.", {"month": "%@"}),
    "%@, 범위 밖": ("{month}, 범위 밖", {"month": "%@"}),
    "%@, 기록한 날 %lld일": ("{month}, 기록한 날 {count}일", {"month": "%1$@", "count": "%2$lld"}),
    "%lld개 선택": ("{count}개 선택", {"count": "%lld"}),
    "설정으로": ("설정으로 돌아가기", {}),
    "이날 기록 편집": ("이날 기록 수정", {}),
    "이날 더보기": ("이날 기록 더 보기", {}),
}

# TP-0239: iOS saves through the system file exporter rather than a browser download.
NATIVE["저장한 기록을 JSON 파일로 내려받아요."] = {
    "en": "Save your notes as a JSON file.", "ja": "保存した記録をJSONファイルとして保存します。",
    "de": "Speichere deine Notizen als JSON-Datei.", "fr": "Enregistrez vos notes au format JSON.",
    "id": "Simpan catatan sebagai file JSON.", "vi": "Lưu các ghi chú dưới dạng tệp JSON.",
    "tr": "Notlarını JSON dosyası olarak kaydet.", "ru": "Сохраните записи в файл JSON.",
    "hi": "सहेजे हुए नोट JSON फ़ाइल में सेव करें।", "th": "บันทึกข้อมูลบันทึกเป็นไฟล์ JSON",
    "pt-BR": "Salve suas anotações em um arquivo JSON.", "es-ES": "Guarda tus notas en un archivo JSON.",
    "es-419": "Guarda tus notas en un archivo JSON.", "zh-Hans": "将已保存的记录存为 JSON 文件。",
    "zh-Hant-TW": "將儲存的紀錄存成 JSON 檔案。", "zh-Hant-HK": "將已儲存的記錄儲存為 JSON 檔案。"}

NO_TRANSLATE = {"", "%lld", "Aa"}
WEEKDAY = {"weekday.sun": 0, "weekday.mon": 1, "weekday.tue": 2, "weekday.wed": 3, "weekday.thu": 4,
           "weekday.fri": 5, "weekday.sat": 6}
KO_DEFAULT = {"kind.word": "단어", "kind.emoji": "이모지", "kind.place": "장소", "kind.time": "시간",
              "level.day": "일간", "level.records": "기록한 날", "level.month": "월간 달력", "level.year": "연간",
              "weekday.sun": "일", "weekday.mon": "월", "weekday.tue": "화", "weekday.wed": "수",
              "weekday.thu": "목", "weekday.fri": "금", "weekday.sat": "토"}

SPEC = re.compile(r'%(?:\d+\$)?(@|lld|d)')

def value_for(key, lang):
    if key in NATIVE: return NATIVE[key].get(lang)
    if key in WEEKDAY: return weekdays[lang][WEEKDAY[key]]
    if key in VIEW_BACK:
        view = web(lang, VIEW_BACK[key])
        return web(lang, "{view} 보기로 돌아가기").replace("{view}", view)
    if key in DERIVED:
        wkey, mapping = DERIVED[key]
        v = web(lang, wkey)
        return None if v is None else convert(v, mapping)
    return web(lang, key)

def unit(v):
    return {"stringUnit": {"state": "translated", "value": v}}

def localization(key, v):
    if isinstance(v, str):
        return unit(v)
    specs = SPEC.findall(key)
    if len(specs) == 1:
        return {"variations": {"plural": {cat: unit(text) for cat, text in v.items()}}}
    # Several arguments: the count goes through a substitution; the other arguments stay positional.
    num = specs.index('lld') + 1
    pos = f'%{num}$lld'
    return {
        "stringUnit": {"state": "translated", "value": "%#@count@"},
        "substitutions": {"count": {
            "argNum": num, "formatSpecifier": "lld",
            "variations": {"plural": {cat: unit(text.replace(pos, '%arg')) for cat, text in v.items()}}}}}

def korean(key):
    """Korean value for a key (the key itself, or the stable-key default). Every key gets one so
    ko.lproj is complete and a Korean app never falls through to the English fallback tables."""
    if key in KO_DEFAULT:
        return unit(KO_DEFAULT[key])
    specs = SPEC.findall(key)
    if 'lld' not in specs:
        return unit(key)
    # Korean has only the "other" plural category; keep the same shape as the other languages.
    counter = iter(range(1, len(specs) + 1))
    positional = SPEC.sub(lambda m: f'%{next(counter)}${m.group(1)}', key)
    if len(specs) == 1:
        return {"variations": {"plural": {"other": unit(key)}}}
    return localization(key, {"other": positional})

strings = {}
missing = []
for key in sorted(keys):
    entry = {}
    if key in NO_TRANSLATE:
        strings[key] = {"shouldTranslate": False}
        continue
    entry["localizations"] = {"ko": korean(key)}
    for lang in LANGS:
        v = value_for(key, lang)
        if v is None:
            missing.append((key, lang))
            continue
        entry["localizations"][APPLE[lang]] = localization(key, v)
    strings[key] = entry

# Never write a catalog with holes: keep the last verified one and say what is missing.
if missing:
    for m in missing: print('MISSING', m, file=sys.stderr)
    sys.exit(f'{len(missing)} translations missing; {OUT} left unchanged')

catalog = {"sourceLanguage": "ko", "strings": strings, "version": "1.0"}
with open(OUT, 'w') as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2, separators=(',', ' : '), sort_keys=True)
    f.write('\n')
print(len(strings), 'keys; 0 missing')

# The trial uses the web's word/place tokens as seeded journal content, separate from interface copy.
samples = {}
for tag in ['ko'] + list(APPLE):
    with open(os.path.join(WEB, 'samples', tag + '.json')) as source:
        samples[APPLE.get(tag, tag)] = json.load(source)
if any(set(words) != set(samples['ko']) for words in samples.values()):
    sys.exit('Sample token sets differ between languages')
with open(os.path.join(HERE, '../../Tokipin/Resources/SampleVocabulary.json'), 'w') as output:
    json.dump(samples, output, ensure_ascii=False, sort_keys=True, indent=2)
    output.write('\n')
