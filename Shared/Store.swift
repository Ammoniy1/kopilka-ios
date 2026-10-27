import Foundation

/// Хранилище данных в общей папке App Group — её видят и приложение, и виджет.
enum Store {
    static let defaultGroup = "group.com.kopilka.app"
    private static let fileName = "kopilka.json"

    /// При установке через AltStore/Sideloadly идентификатор группы меняется,
    /// поэтому берём настоящий из профиля подписи или из Info.plist.
    static func groupCandidates() -> [String] {
        var result: [String] = []
        func add(_ list: [String]?) {
            for g in list ?? [] where !result.contains(g) { result.append(g) }
        }
        let bundles: [Bundle] = {
            var b = [Bundle.main]
            // внутри виджета: Kopilka.app/PlugIns/KopilkaWidget.appex → Kopilka.app
            let parent = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            if parent.pathExtension == "app", let pb = Bundle(url: parent) { b.append(pb) }
            return b
        }()
        for b in bundles { add(provisionedGroups(in: b)) }
        for b in bundles { add(b.object(forInfoDictionaryKey: "ALTAppGroups") as? [String]) }
        add([defaultGroup])
        return result
    }

    private static func provisionedGroups(in bundle: Bundle) -> [String]? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let raw = String(data: data, encoding: .isoLatin1),
              let start = raw.range(of: "<?xml"),
              let end = raw.range(of: "</plist>") else { return nil }
        let xml = String(raw[start.lowerBound..<end.upperBound])
        guard let plistData = xml.data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let ent = plist["Entitlements"] as? [String: Any] else { return nil }
        return ent["com.apple.security.application-groups"] as? [String]
    }

    static let directory: URL = {
        for g in groupCandidates() {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: g) {
                return url
            }
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    static var isShared: Bool {
        groupCandidates().contains { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
    }

    static var fileURL: URL { directory.appendingPathComponent(fileName) }

    static func load() -> AppData {
        guard let data = try? Data(contentsOf: fileURL),
              let d = try? JSONDecoder().decode(AppData.self, from: data) else { return AppData() }
        return d
    }

    static func save(_ d: AppData) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        if let data = try? enc.encode(d) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

// MARK: - Перенос данных из версии для Scriptable

enum ScriptableImport {
    /// Принимает JSON, скопированный кнопкой «Экспорт» в Scriptable.
    static func parse(_ text: String, into base: AppData) -> AppData? {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let goals = root["goals"] as? [String: Any], !goals.isEmpty else { return nil }
        var d = base
        var idMap: [String: UUID] = [:]
        let sorted = goals.sorted { a, b in
            let na = (a.value as? [String: Any])?["num"] as? Int ?? 0
            let nb = (b.value as? [String: Any])?["num"] as? Int ?? 0
            return na < nb
        }
        for (key, value) in sorted {
            guard let g = value as? [String: Any] else { continue }
            let history: [Entry] = (g["history"] as? [[String: Any]] ?? []).compactMap { h in
                guard let t = (h["t"] as? NSNumber)?.doubleValue, let a = (h["a"] as? NSNumber)?.doubleValue else { return nil }
                return Entry(date: Date(timeIntervalSince1970: t / 1000), amount: a, note: h["n"] as? String ?? "")
            }
            let p = Piggy(num: d.nextNum,
                          name: g["name"] as? String ?? "Копилка",
                          emoji: g["emoji"] as? String ?? "🐷",
                          target: (g["target"] as? NSNumber)?.doubleValue ?? 1000,
                          saved: (g["saved"] as? NSNumber)?.doubleValue ?? 0,
                          history: history)
            d.nextNum += 1
            d.piggies.append(p)
            idMap[key] = p.id
        }
        if d.mainID == nil, let m = root["main"] as? String { d.mainID = idMap[m] }
        if d.mainID == nil { d.mainID = d.piggies.first?.id }
        if let t = root["widgetTheme"] as? String { d.widgetTheme = t == "auto" ? .system : ThemeChoice(rawValue: t) ?? .system }
        if let t = root["appTheme"] as? String { d.appTheme = t == "auto" ? .system : ThemeChoice(rawValue: t) ?? .system }
        return d
    }
}
