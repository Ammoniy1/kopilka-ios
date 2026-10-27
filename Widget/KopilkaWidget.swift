import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Настройки виджета: какая копилка и какое оформление

struct PiggyEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Копилка"
    static var defaultQuery = PiggyQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ p: Piggy) {
        id = p.id
        name = "\(p.emoji) \(p.name)"
    }
}

struct PiggyQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [PiggyEntity] {
        Store.load().piggies.filter { identifiers.contains($0.id) }.map(PiggyEntity.init)
    }

    func suggestedEntities() async throws -> [PiggyEntity] {
        Store.load().piggies.map(PiggyEntity.init)
    }
}

enum WidgetTheme: String, AppEnum {
    case app, system, light, dark

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Оформление"
    static var caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .app: "Как в приложении",
        .system: "Как в системе",
        .light: "Светлое",
        .dark: "Тёмное",
    ]
}

struct KopilkaIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Копилка"
    static var description = IntentDescription("Выбери копилку и оформление виджета.")

    @Parameter(title: "Копилка")
    var piggy: PiggyEntity?

    @Parameter(title: "Оформление", default: .app)
    var theme: WidgetTheme
}

// MARK: - Данные для отрисовки

struct PiggyEntry: TimelineEntry {
    let date: Date
    let piggy: Piggy?
    let theme: ThemeChoice
    let currency: String

    static var sample: PiggyEntry {
        let d = AppData.sample
        return PiggyEntry(date: Date(), piggy: d.piggies.first, theme: .system, currency: d.currency)
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PiggyEntry { .sample }

    func snapshot(for configuration: KopilkaIntent, in context: Context) async -> PiggyEntry {
        let e = makeEntry(configuration)
        return e.piggy == nil && context.isPreview ? .sample : e
    }

    func timeline(for configuration: KopilkaIntent, in context: Context) async -> Timeline<PiggyEntry> {
        // приложение само обновляет виджет при каждом изменении; это — подстраховка
        Timeline(entries: [makeEntry(configuration)], policy: .after(Date().addingTimeInterval(3 * 3600)))
    }

    private func makeEntry(_ c: KopilkaIntent) -> PiggyEntry {
        let d = Store.load()
        let piggy = d.piggy(c.piggy?.id) ?? d.mainPiggy
        let theme: ThemeChoice
        switch c.theme {
        case .app: theme = d.widgetTheme
        case .system: theme = .system
        case .light: theme = .light
        case .dark: theme = .dark
        }
        return PiggyEntry(date: Date(), piggy: piggy, theme: theme, currency: d.currency)
    }
}

// MARK: - Вид

struct KopilkaWidgetView: View {
    let entry: PiggyEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    private var dark: Bool { entry.theme.isDark(system: scheme == .dark) }
    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }

    var body: some View {
        let pal = Palette(dark: dark)
        content(pal)
            .containerBackground(for: .widget) { isAccessory ? Color.clear : pal.bg }
            .widgetURL(URL(string: "kopilka://piggy/\(entry.piggy?.id.uuidString ?? "main")"))
    }

    @ViewBuilder
    private func content(_ pal: Palette) -> some View {
        if let p = entry.piggy {
            switch family {
            case .accessoryInline: Text("\(p.emoji) \(Fmt.percent(p.progress)) · \(Fmt.short(p.saved, entry.currency))")
            case .accessoryCircular: circular(p)
            case .accessoryRectangular: rectangular(p)
            case .systemSmall: small(p, pal)
            case .systemLarge, .systemExtraLarge: large(p, pal)
            default: medium(p, pal)
            }
        } else {
            VStack(spacing: 6) {
                Image(Pig.imageName(0, dark: dark)).resizable().scaledToFit()
                Text("Открой приложение и создай копилку")
                    .font(.rounded(12, .semibold)).foregroundStyle(pal.text)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func pig(_ p: Piggy) -> some View {
        Image(Pig.imageName(p.progress, dark: dark)).resizable().scaledToFit()
    }

    private func amountColor(_ p: Piggy, _ pal: Palette) -> Color { p.isDone ? pal.done : pal.text }
    private func pctColor(_ p: Piggy, _ pal: Palette) -> Color { p.isDone ? pal.done : pal.accent }

    // маленький: свинка в центре, сумма и полоска снизу
    private func small(_ p: Piggy, _ pal: Palette) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(p.emoji) \(p.name)").font(.rounded(12, .semibold)).foregroundStyle(pal.sub).lineLimit(1)
            pig(p).frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(alignment: .lastTextBaseline) {
                Text(Fmt.short(p.saved, entry.currency))
                    .font(.rounded(17, .heavy)).foregroundStyle(amountColor(p, pal))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text(p.isDone ? "🎉" : Fmt.percent(p.progress))
                    .font(.rounded(15, .heavy)).foregroundStyle(pctColor(p, pal))
            }
            ProgressBar(progress: p.progress, pal: pal, height: 6)
        }
    }

    // средний: свинка слева, цифры справа
    private func medium(_ p: Piggy, _ pal: Palette) -> some View {
        HStack(spacing: 12) {
            pig(p).frame(width: 118)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(p.emoji) \(p.name)").font(.rounded(15, .bold)).foregroundStyle(pal.text).lineLimit(1)
                Text(Fmt.money(p.saved, entry.currency))
                    .font(.rounded(24, .heavy)).foregroundStyle(amountColor(p, pal))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.top, 2)
                Text("из " + Fmt.money(p.target, entry.currency))
                    .font(.rounded(12, .medium)).foregroundStyle(pal.sub)
                ProgressBar(progress: p.progress, pal: pal, height: 8).padding(.top, 6)
                HStack {
                    Text(p.isDone ? "🎉 Готово!" : Fmt.percent(p.progress))
                        .font(.rounded(12, .bold)).foregroundStyle(pctColor(p, pal))
                    Spacer()
                    if !p.isDone {
                        Text("ещё " + Fmt.short(p.left, entry.currency))
                            .font(.rounded(12, .medium)).foregroundStyle(pal.sub)
                    }
                }
                .padding(.top, 3)
                if let last = p.history.last {
                    Text((last.amount >= 0 ? "+" : "−") + Fmt.short(abs(last.amount), entry.currency) + " · " + Fmt.ago(last.date))
                        .font(.rounded(11, .medium)).foregroundStyle(pal.sub)
                        .padding(.top, 2)
                }
            }
        }
    }

    // большой: шапка, крупная свинка, прогресс, последние пополнения
    private func large(_ p: Piggy, _ pal: Palette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(p.emoji) \(p.name)").font(.rounded(17, .bold)).foregroundStyle(pal.text).lineLimit(1)
                Spacer()
                Text(p.isDone ? "🎉 100%" : Fmt.percent(p.progress))
                    .font(.rounded(17, .heavy)).foregroundStyle(pctColor(p, pal))
            }
            pig(p).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 4)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(Fmt.money(p.saved, entry.currency))
                    .font(.rounded(28, .heavy)).foregroundStyle(amountColor(p, pal))
                Text("из " + Fmt.money(p.target, entry.currency))
                    .font(.rounded(14, .medium)).foregroundStyle(pal.sub)
            }
            .lineLimit(1).minimumScaleFactor(0.6)
            ProgressBar(progress: p.progress, pal: pal, height: 8).padding(.top, 8)
            HStack {
                Text(p.isDone ? "Цель достигнута!" : "ещё " + Fmt.money(p.left, entry.currency))
                    .font(.rounded(12, .medium)).foregroundStyle(pal.sub)
                Spacer()
                if let f = Fmt.forecast(p) {
                    Text("≈ к " + Fmt.date(f)).font(.rounded(12, .semibold)).foregroundStyle(pal.accent)
                }
            }
            .padding(.top, 5)
            let hist = Array(p.history.suffix(3).reversed())
            if !hist.isEmpty {
                VStack(spacing: 4) {
                    ForEach(hist) { h in
                        HStack(spacing: 6) {
                            Text((h.amount >= 0 ? "+" : "−") + Fmt.money(abs(h.amount), entry.currency))
                                .font(.rounded(13, .semibold)).foregroundStyle(h.amount >= 0 ? pal.text : pal.minus)
                            if !h.note.isEmpty {
                                Text(h.note).font(.rounded(12, .medium)).foregroundStyle(pal.sub).lineLimit(1)
                            }
                            Spacer()
                            Text(Fmt.ago(h.date)).font(.rounded(12, .medium)).foregroundStyle(pal.sub)
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
    }

    private func circular(_ p: Piggy) -> some View {
        Gauge(value: min(1, max(0, p.progress))) {
            Text(p.emoji)
        } currentValueLabel: {
            Text("\(Int(floor(min(1, p.progress) * 100)))")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private func rectangular(_ p: Piggy) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(p.emoji) \(p.name)").font(.rounded(13, .semibold)).lineLimit(1)
            Text("\(Fmt.short(p.saved, entry.currency)) из \(Fmt.short(p.target, entry.currency))")
                .font(.rounded(15, .bold)).lineLimit(1).minimumScaleFactor(0.7)
            ProgressView(value: min(1, max(0, p.progress)))
        }
    }
}

// MARK: - Виджет

struct KopilkaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "KopilkaWidget", intent: KopilkaIntent.self, provider: Provider()) { entry in
            KopilkaWidgetView(entry: entry)
        }
        .configurationDisplayName("Копилка")
        .description("Свинка-копилка с прогрессом к цели.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct KopilkaWidgetBundle: WidgetBundle {
    var body: some Widget {
        KopilkaWidget()
    }
}
