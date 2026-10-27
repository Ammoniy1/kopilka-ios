import Foundation

/// Одна операция: пополнение (+) или снятие (−)
struct Entry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var amount: Double
    var note: String
}

/// Копилка на цель
struct Piggy: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var num: Int
    var name: String
    var emoji: String
    var target: Double
    var saved: Double
    var history: [Entry] = []

    var progress: Double { target > 0 ? saved / target : 0 }
    var isDone: Bool { progress >= 1 }
    var left: Double { max(0, target - saved) }
}

enum ThemeChoice: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "🌓 Авто"
        case .light: return "☀️ Светлое"
        case .dark: return "🌙 Тёмное"
        }
    }
    func isDark(system: Bool) -> Bool {
        switch self {
        case .system: return system
        case .light: return false
        case .dark: return true
        }
    }
}

struct AppData: Codable {
    var piggies: [Piggy] = []
    var mainID: UUID?
    var nextNum: Int = 1
    var appTheme: ThemeChoice = .system
    var widgetTheme: ThemeChoice = .system
    var currency: String = "₪"

    init() {}

    enum CodingKeys: String, CodingKey {
        case piggies, mainID, nextNum, appTheme, widgetTheme, currency
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        piggies = (try? c.decodeIfPresent([Piggy].self, forKey: .piggies)) ?? []
        mainID = try? c.decodeIfPresent(UUID.self, forKey: .mainID)
        nextNum = (try? c.decodeIfPresent(Int.self, forKey: .nextNum)) ?? 1
        appTheme = (try? c.decodeIfPresent(ThemeChoice.self, forKey: .appTheme)) ?? .system
        widgetTheme = (try? c.decodeIfPresent(ThemeChoice.self, forKey: .widgetTheme)) ?? .system
        currency = (try? c.decodeIfPresent(String.self, forKey: .currency)) ?? "₪"
    }

    var mainPiggy: Piggy? {
        if let id = mainID, let p = piggies.first(where: { $0.id == id }) { return p }
        return piggies.first
    }

    func piggy(_ id: UUID?) -> Piggy? {
        guard let id else { return nil }
        return piggies.first { $0.id == id }
    }

    static var sample: AppData {
        var d = AppData()
        let p = Piggy(num: 1, name: "Отпуск", emoji: "🏖️", target: 5000, saved: 1840,
                      history: [Entry(date: Date(), amount: 1840, note: "")])
        d.piggies = [p]
        d.mainID = p.id
        d.nextNum = 2
        return d
    }
}

// MARK: - Стадии свинки

enum Pig {
    /// 0 — пустая, 7 — полная; между ними 6 промежуточных стадий
    static func stage(_ p: Double) -> Int {
        if p >= 1 { return 7 }
        if p <= 0 { return 0 }
        return min(6, 1 + Int(floor(p * 6)))
    }

    static func imageName(_ p: Double, dark: Bool) -> String {
        "pig-\(dark ? "dark" : "light")-\(stage(p))"
    }
}

// MARK: - Форматирование

enum Fmt {
    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 0
        return f
    }()

    static func money(_ v: Double, _ cur: String) -> String {
        let a = abs(v)
        numberFormatter.maximumFractionDigits = a.rounded() == a ? 0 : 2
        let s = numberFormatter.string(from: NSNumber(value: a)) ?? "\(a)"
        return (v < 0 ? "−" : "") + s + " " + cur
    }

    static func short(_ v: Double, _ cur: String) -> String {
        let a = abs(v)
        func trim(_ x: Double) -> String {
            let s = String(format: "%.1f", x)
            return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
        }
        if a >= 1_000_000 { return (v < 0 ? "−" : "") + trim(a / 1_000_000) + "M " + cur }
        if a >= 10_000 { return (v < 0 ? "−" : "") + trim(a / 1_000) + "K " + cur }
        return money(v, cur)
    }

    static func percent(_ p: Double) -> String { "\(Int(floor(max(0, p) * 100)))%" }

    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f
    }()

    private static let dayMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    static func ago(_ d: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day ?? 0
        if days <= 0 { return "сегодня" }
        if days == 1 { return "вчера" }
        if days < 7 { return "\(days) дн. назад" }
        return dayMonth.string(from: d)
    }

    static func date(_ d: Date) -> String {
        Calendar.current.isDate(d, equalTo: Date(), toGranularity: .year) ? dayMonth.string(from: d) : dayMonthYear.string(from: d)
    }

    /// Когда накопишь при текущем темпе
    static func forecast(_ p: Piggy) -> Date? {
        guard let first = p.history.first, p.saved > 0, !p.isDone else { return nil }
        let days = Date().timeIntervalSince(first.date) / 86400
        guard days >= 3 else { return nil }
        let left = p.left / (p.saved / days)
        guard left.isFinite, left < 3650 else { return nil }
        return Date().addingTimeInterval(left * 86400)
    }

    static func parse(_ s: String) -> Double? {
        let t = s.filter { !$0.isWhitespace }.replacingOccurrences(of: ",", with: ".")
        return Double(t)
    }
}
