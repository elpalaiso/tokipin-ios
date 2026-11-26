import Foundation
let ids = ["en","ja","de","fr","id","vi","tr","ru","hi","th","pt-BR","es-ES","es-419","zh-Hans","zh-Hant-TW","zh-Hant-HK"]
var out: [String: [String]] = [:]
for id in ids {
    var cal = Calendar(identifier: .gregorian)
    cal.locale = Locale(identifier: id)
    out[id] = cal.shortStandaloneWeekdaySymbols
}
let data = try! JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
print(String(data: data, encoding: .utf8)!)
