import Foundation

/// Sample records identical to the homepage trial (tokipin/trial.js + trial-content.js):
/// the same seeded generator, themes and Korean words, over the three years ending today.
/// Used by the in-memory first-launch trial and debug fixtures.
enum SampleGenerator {
    struct Theme {
        let words: [String]
        let places: [String]
        let emoji: [String]
        let from: Int
        let to: Int
    }

    /// The web's seeded integer mixer (mulberry32), so a day gets the same entries everywhere.
    struct Random {
        private var seed: Int32

        init(_ seed: Int) { self.seed = Int32(truncatingIfNeeded: seed) }

        mutating func callAsFunction(_ limit: Int) -> Int {
            seed = seed &+ Int32(bitPattern: 0x6d2b79f5)
            var bits = (seed ^ Int32(bitPattern: UInt32(bitPattern: seed) >> 15)) &* (seed | 1)
            bits ^= bits &+ ((bits ^ Int32(bitPattern: UInt32(bitPattern: bits) >> 7)) &* (bits | 61))
            let value = UInt32(bitPattern: bits ^ Int32(bitPattern: UInt32(bitPattern: bits) >> 14))
            return Int(Double(value) / 4294967296 * Double(limit))
        }
    }

    static let arrangements: [[ItemKind]] = [
        [.word], [.emoji], [.place, .word], [.word, .emoji],
        [.word, .place, .emoji], [.time, .place, .word], [.emoji, .word, .time],
        [.word, .emoji, .place, .time], [.time, .word, .place, .emoji],
        [.place, .word, .emoji, .word], [.emoji, .time, .word, .place],
        [.word, .place, .time, .word, .emoji], [.time, .emoji, .word, .place, .word, .emoji]
    ]

    /// Days since 1970-01-01 for a calendar day (the web's numberFromKey).
    static func dayNumber(_ day: DayKey) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let date = utc.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
        return Int((date.timeIntervalSince1970 / 86400).rounded())
    }

    static func day(fromNumber number: Int) -> DayKey {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let parts = utc.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(number) * 86400))
        return DayKey(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// One or two spaced quiet dates per nine-day block leave real empty days.
    static func hasSample(_ day: Int) -> Bool {
        let block = Int((Double(day) / 9).rounded(.down))
        let offset = day - block * 9
        var roll = Random(block)
        let first = 1 + roll(7)
        if offset == first { return false }
        if roll(2) == 0 { return true }
        let candidates = [1, 2, 3, 4, 5, 6, 7].filter { abs($0 - first) > 1 }
        return offset != candidates[roll(candidates.count)]
    }

    static func items(for key: DayKey, vocabulary: [String: String] = words, starter: Bool = false) -> [RecordItem] {
        let number = dayNumber(key)
        var roll = Random(number)
        let theme = themes[roll(themes.count)]
        let sequence: [ItemKind] = starter ? [.word, .emoji, .place, .time] : arrangements[roll(arrangements.count)]
        var pools: [ItemKind: [String]] = [.word: theme.words, .emoji: theme.emoji, .place: theme.places]
        var items: [RecordItem] = []
        for kind in sequence {
            let value: String
            if kind == .time {
                let hour = theme.from + roll(theme.to - theme.from + 1)
                value = TimeRules.canonical(hour: hour, minute: roll(12) * 5)
            } else {
                guard var pool = pools[kind], !pool.isEmpty else { continue }
                let token = pool.remove(at: roll(pool.count))
                pools[kind] = pool
                value = kind == .emoji ? token : (vocabulary[token] ?? token)
            }
            let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012llx", UInt64(truncatingIfNeeded: number * 16 + items.count) & 0xffffffffffff))!
            items.append(RecordItem(id: id, kind: kind, value: value))
        }
        return items
    }

    /// Three years ending today, like the homepage trial.
    static func archive(today: DayKey = .today, years: Int = 3, vocabulary: [String: String] = words) -> RecordArchive {
        let start = firstDay(today: today, years: years)
        var days: [RecordArchive.Day] = []
        for number in dayNumber(start)...dayNumber(today) where hasSample(number) {
            let key = day(fromNumber: number)
            days.append(.init(date: key, items: items(for: key, vocabulary: vocabulary), updatedAt: key.date))
        }
        return RecordArchive(days: days)
    }

    /// The day after the same date `years` earlier (the web's firstDay uses 3).
    /// `years: 10` is the shared large-data seed for performance checks.
    static func firstDay(today: DayKey, years: Int = 3) -> DayKey {
        let last = MonthKey(year: today.year - years, month: today.month).numberOfDays
        let anniversary = DayKey(year: today.year - years, month: today.month, day: min(today.day, last))
        return day(fromNumber: dayNumber(anniversary) + 1)
    }

    static let localizedWords: [String: String] = {
        guard let url = Bundle.main.url(forResource: "SampleVocabulary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let languages = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return words }
        return languages[Bundle.main.preferredLocalizations.first ?? "en"] ?? languages["en"] ?? words
    }()

    /// Korean column of the homepage vocabulary (trial-content.js).
    static let words: [String: String] = [
        "walk": "산책",
        "dawn": "새벽",
        "birdsong": "새소리",
        "breeze": "산들바람",
        "leaves": "나뭇잎",
        "shade": "그늘",
        "tea": "차 한 잔",
        "teapot": "찻주전자",
        "steam": "김",
        "coffee": "커피",
        "firstSip": "첫 모금",
        "cup": "머그잔",
        "cycling": "자전거 타기",
        "pedals": "페달",
        "swim": "수영",
        "ripples": "물결",
        "goggles": "물안경",
        "melody": "멜로디",
        "headphones": "헤드폰",
        "favoriteSong": "좋아하는 노래",
        "reading": "독서",
        "bookmark": "책갈피",
        "lastPage": "마지막 장",
        "tomatoes": "토마토",
        "basket": "바구니",
        "herbs": "허브",
        "cooking": "요리",
        "soup": "수프",
        "simmer": "보글보글",
        "sunset": "노을",
        "clouds": "구름",
        "pinkSky": "분홍빛 하늘",
        "umbrella": "우산",
        "puddles": "물웅덩이",
        "raindrops": "빗방울",
        "sketch": "스케치",
        "pencil": "연필",
        "portrait": "초상화",
        "bloom": "첫 꽃",
        "watering": "물주기",
        "sprout": "새싹",
        "dough": "반죽",
        "loaf": "갓 구운 빵",
        "crust": "빵 껍질",
        "blanket": "담요",
        "picnic": "피크닉",
        "grapes": "포도",
        "waves": "파도",
        "sand": "모래",
        "shells": "조개껍데기",
        "stones": "조약돌",
        "reflection": "물에 비친 하늘",
        "train": "기차",
        "windowSeat": "창가 자리",
        "ticket": "표 한 장",
        "stars": "별빛",
        "moon": "달",
        "nightSky": "밤하늘",
        "camera": "카메라",
        "shadow": "그림자",
        "photo": "사진 한 장",
        "pottery": "도예",
        "clay": "찰흙",
        "bowl": "작은 그릇",
        "puzzle": "퍼즐",
        "lastPiece": "마지막 조각",
        "corners": "모서리 조각",
        "letter": "편지",
        "envelope": "봉투",
        "handwriting": "손글씨",
        "climbing": "오르막길",
        "view": "탁 트인 풍경",
        "footsteps": "발걸음",
        "stretching": "스트레칭",
        "breathing": "심호흡",
        "balance": "균형",
        "painting": "그림",
        "sculpture": "조각상",
        "blue": "파랑",
        "candle": "촛불",
        "quiet": "고요함",
        "journal": "일기",
        "home": "집",
        "park": "공원",
        "garden": "정원",
        "trail": "산책로",
        "riverside": "강변",
        "lake": "호숫가",
        "pool": "수영장",
        "kitchen": "부엌",
        "cafe": "카페",
        "library": "도서관",
        "bookshop": "서점",
        "market": "시장",
        "balcony": "발코니",
        "window": "창가",
        "street": "골목",
        "studio": "작업실",
        "bakery": "빵집",
        "beach": "해변",
        "bridge": "다리 위",
        "station": "기차역",
        "hill": "언덕",
        "table": "식탁",
        "desk": "책상",
        "hilltop": "언덕 꼭대기",
        "gym": "체육관",
        "gallery": "미술관",
        "exhibition": "전시장",
    ]

    static let themes: [Theme] = [
        Theme(words: ["dawn","walk","birdsong"], places: ["park","trail"], emoji: ["🐦","🌅","🚶"], from: 5, to: 10),
        Theme(words: ["shade","breeze","leaves"], places: ["garden","park"], emoji: ["🍃","🌳","☁️"], from: 9, to: 17),
        Theme(words: ["tea","steam","teapot"], places: ["home","cafe"], emoji: ["🍵","🫖"], from: 7, to: 20),
        Theme(words: ["firstSip","coffee","cup"], places: ["kitchen","cafe"], emoji: ["☕","🫘"], from: 6, to: 16),
        Theme(words: ["cycling","breeze","pedals"], places: ["park","riverside"], emoji: ["🚲","🍃"], from: 7, to: 18),
        Theme(words: ["ripples","swim","goggles"], places: ["pool"], emoji: ["🏊","💧","🥽"], from: 7, to: 20),
        Theme(words: ["favoriteSong","melody","headphones"], places: ["home","cafe"], emoji: ["🎧","🎶"], from: 8, to: 22),
        Theme(words: ["reading","lastPage","bookmark"], places: ["library","bookshop"], emoji: ["📖","🔖","📚"], from: 9, to: 19),
        Theme(words: ["basket","tomatoes","herbs"], places: ["market"], emoji: ["🧺","🍅","🌿"], from: 8, to: 16),
        Theme(words: ["cooking","soup","simmer"], places: ["kitchen"], emoji: ["🥣","🥕","🍲"], from: 11, to: 20),
        Theme(words: ["sunset","pinkSky","clouds"], places: ["bridge","balcony"], emoji: ["🌇","☁️"], from: 16, to: 21),
        Theme(words: ["raindrops","umbrella","puddles"], places: ["street","park"], emoji: ["☔","💧","🌧️"], from: 7, to: 18),
        Theme(words: ["sketch","pencil","portrait"], places: ["studio","desk"], emoji: ["✏️","🎨"], from: 9, to: 21),
        Theme(words: ["sprout","watering","bloom"], places: ["garden","balcony"], emoji: ["🌱","💧","🌼"], from: 7, to: 17),
        Theme(words: ["dough","loaf","crust"], places: ["kitchen","bakery"], emoji: ["🍞","🥖"], from: 6, to: 17),
        Theme(words: ["picnic","grapes","blanket"], places: ["park","lake"], emoji: ["🧺","🍇","☀️"], from: 10, to: 16),
        Theme(words: ["waves","shells","sand"], places: ["beach"], emoji: ["🌊","🐚"], from: 7, to: 19),
        Theme(words: ["reflection","ripples","stones"], places: ["lake","riverside"], emoji: ["💧","🪨"], from: 7, to: 18),
        Theme(words: ["train","ticket","windowSeat"], places: ["station"], emoji: ["🚆","🎫"], from: 6, to: 21),
        Theme(words: ["nightSky","moon","stars"], places: ["hill","balcony"], emoji: ["🌙","✨","🔭"], from: 18, to: 23),
        Theme(words: ["photo","camera","shadow"], places: ["street","park"], emoji: ["📸","☀️"], from: 8, to: 19),
        Theme(words: ["pottery","clay","bowl"], places: ["studio"], emoji: ["🏺","👐"], from: 9, to: 18),
        Theme(words: ["puzzle","corners","lastPiece"], places: ["table","home"], emoji: ["🧩","💡"], from: 10, to: 22),
        Theme(words: ["letter","envelope","handwriting"], places: ["desk","home"], emoji: ["✉️","🖋️"], from: 8, to: 21),
        Theme(words: ["climbing","footsteps","view"], places: ["hilltop","trail"], emoji: ["🥾","⛰️"], from: 7, to: 17),
        Theme(words: ["stretching","breathing","balance"], places: ["home","gym"], emoji: ["🧘","🌿"], from: 7, to: 20),
        Theme(words: ["painting","blue","sculpture"], places: ["gallery","exhibition"], emoji: ["🖼️","🎨"], from: 9, to: 18),
        Theme(words: ["quiet","candle","journal"], places: ["desk","window"], emoji: ["🕯️","📓"], from: 17, to: 23),
    ]
}
