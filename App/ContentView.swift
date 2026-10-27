import SwiftUI
import UIKit

enum SheetKind: Identifiable {
    case add, withdraw, create, edit
    var id: Int { hashValue }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var sheet: SheetKind?
    @State private var confirmDelete = false
    @State private var fallingCoins: [UUID] = []
    @State private var bounce = 0
    @State private var showConfetti = false

    /// Системная тема запоминается отдельно, т.к. preferredColorScheme её подменяет
    @State private var systemIsDark = false

    private var dark: Bool { model.data.appTheme.isDark(system: systemIsDark) }

    var body: some View {
        let pal = Palette(dark: dark)
        ZStack(alignment: .bottom) {
            pal.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header(pal)
                    chips(pal)
                    if let p = model.selected {
                        piggyScreen(p, pal)
                    } else {
                        emptyState(pal)
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            if let t = model.toast {
                ToastView(message: t) { withAnimation { model.undo() } }
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(t.id)
                    .task(id: t.id) {
                        try? await Task.sleep(for: .seconds(3.5))
                        if model.toast?.id == t.id { withAnimation { model.toast = nil } }
                    }
            }

            if showConfetti { ConfettiView() }
        }
        .animation(.spring(duration: 0.3), value: model.toast)
        .preferredColorScheme(model.data.appTheme == .system ? nil : (dark ? .dark : .light))
        .tint(pal.pink)
        .sheet(item: $sheet) { kind in
            switch kind {
            case .add: AmountSheet(sign: 1, pal: pal)
            case .withdraw: AmountSheet(sign: -1, pal: pal)
            case .create: EditSheet(isNew: true, pal: pal)
            case .edit: EditSheet(isNew: false, pal: pal)
            }
        }
        .environment(model)
        .confirmationDialog("Удалить копилку «\(model.selected?.name ?? "")»?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { withAnimation { model.deleteSelected() } }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Копилка и вся её история пропадут.")
        }
        .onChange(of: model.coinDrops) { dropCoin() }
        .onChange(of: model.celebrate) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showConfetti = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { showConfetti = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.reloadFromDisk() }
        }
        .onAppear { systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark }
        .onChange(of: systemScheme) { _, s in
            if model.data.appTheme == .system { systemIsDark = s == .dark }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.coinDrops)
        .sensoryFeedback(.success, trigger: model.celebrate)
    }

    // MARK: - Шапка и список копилок

    private func header(_ pal: Palette) -> some View {
        HStack {
            Text("Копилки").font(.rounded(32, .heavy)).foregroundStyle(pal.text)
            Spacer()
            Button { withAnimation(.easeInOut(duration: 0.3)) { model.cycleAppTheme() } } label: {
                Text(model.data.appTheme == .system ? "🌓" : model.data.appTheme == .dark ? "🌙" : "☀️")
                    .font(.system(size: 19))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(pal.card))
                    .overlay(Circle().strokeBorder(pal.line))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func chips(_ pal: Palette) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(model.data.piggies) { p in
                        let on = p.id == model.selected?.id
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { model.selectedID = p.id }
                        } label: {
                            HStack(spacing: 6) {
                                Text("\(p.emoji) \(p.name)").font(.rounded(15, .semibold))
                                Text(Fmt.percent(p.progress) + (p.id == model.data.mainID ? " ★" : ""))
                                    .font(.rounded(12, .semibold)).opacity(0.75)
                            }
                            .foregroundStyle(on ? Color.white : pal.text)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(on ? pal.pink : pal.card))
                            .overlay(Capsule().strokeBorder(on ? Color.clear : pal.line))
                        }
                        .id(p.id)
                    }
                    Button { sheet = .create } label: {
                        Text("＋ Новая").font(.rounded(15, .semibold)).foregroundStyle(pal.pink)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(pal.card))
                            .overlay(Capsule().strokeBorder(pal.line))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.selected?.id) { _, id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
    }

    // MARK: - Экран копилки

    @ViewBuilder
    private func piggyScreen(_ p: Piggy, _ pal: Palette) -> some View {
        let name = Pig.imageName(p.progress, dark: dark)

        // большая свинка
        ZStack(alignment: .top) {
            ZStack {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .id(name)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.5), value: name)
            .phaseAnimator([1.0, 1.05, 0.97, 1.0], trigger: bounce) { content, s in
                content.scaleEffect(x: CGFloat(s), y: CGFloat(2 - s), anchor: .bottom)
            } animation: { _ in .spring(duration: 0.18) }

            ForEach(fallingCoins, id: \.self) { _ in
                FallingCoin().offset(x: 6, y: 30)
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24)
        .padding(.top, 8)

        // название и суммы
        VStack(spacing: 4) {
            Text("\(p.emoji) \(p.name)")
                .font(.rounded(25, .heavy)).foregroundStyle(pal.text)
                .multilineTextAlignment(.center)

            if p.id == model.data.mainID {
                Text("★ Главная — в виджетах по умолчанию")
                    .font(.rounded(13, .bold)).foregroundStyle(pal.pink)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(pal.pinkSoft))
            } else {
                Button("☆ Сделать главной") { model.makeMain() }
                    .font(.rounded(13, .semibold)).foregroundStyle(pal.sub)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Fmt.money(p.saved, model.currency))
                    .font(.rounded(42, .heavy))
                    .foregroundStyle(p.isDone ? pal.done : pal.text)
                    .contentTransition(.numericText(value: p.saved))
                Text("из " + Fmt.money(p.target, model.currency))
                    .font(.rounded(17, .semibold)).foregroundStyle(pal.sub)
            }
            .lineLimit(1).minimumScaleFactor(0.6)
            .padding(.top, 10)
            .animation(.snappy, value: p.saved)

            ProgressBar(progress: p.progress, pal: pal)
                .animation(.spring(duration: 0.7), value: p.progress)
                .padding(.top, 8)

            HStack {
                Text(p.isDone ? "🎉 Цель достигнута!" : Fmt.percent(p.progress))
                    .font(.rounded(15, .bold)).foregroundStyle(p.isDone ? pal.done : pal.accent)
                Spacer()
                if !p.isDone {
                    Text("ещё " + Fmt.money(p.left, model.currency))
                        .font(.rounded(15, .semibold)).foregroundStyle(pal.sub)
                }
            }
            .padding(.top, 4)

            if let f = Fmt.forecast(p) {
                Text("В таком темпе накопишь к \(Fmt.date(f))")
                    .font(.rounded(14)).foregroundStyle(pal.sub)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)

        // кнопки
        HStack(spacing: 10) {
            Button { sheet = .withdraw } label: {
                Text("− Снять").font(.rounded(17, .bold)).foregroundStyle(pal.text)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(pal.card))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(pal.line))
            }
            Button { sheet = .add } label: {
                Text("+ Пополнить").font(.rounded(17, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(pal.pink))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)

        HStack(spacing: 8) {
            ForEach([10, 50, 100, 500], id: \.self) { v in
                Button { withAnimation { model.change(by: Double(v)) } } label: {
                    Text("+\(v)").font(.rounded(15, .bold)).foregroundStyle(pal.pink)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(pal.pinkSoft))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)

        historyCard(p, pal)
        widgetCard(pal)
        appearanceCard(pal)
        piggyCard(pal)
    }

    private func dropCoin() {
        let id = UUID()
        fallingCoins.append(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { bounce += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { fallingCoins.removeAll { $0 == id } }
    }

    // MARK: - Карточки

    private func card<Content: View>(_ title: String, _ pal: Palette, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.rounded(13, .semibold)).kerning(0.6).foregroundStyle(pal.sub)
                .padding(.top, 14).padding(.bottom, 6)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(pal.card))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(pal.line))
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }

    private func historyCard(_ p: Piggy, _ pal: Palette) -> some View {
        card("История", pal) {
            let items = Array(p.history.reversed().prefix(40))
            if items.isEmpty {
                Text("Пока пусто — пополни копилку").font(.rounded(15)).foregroundStyle(pal.sub)
                    .padding(.vertical, 12)
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { i, e in
                if i > 0 { Divider().overlay(pal.line) }
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text((e.amount >= 0 ? "+" : "−") + Fmt.money(abs(e.amount), model.currency))
                            .font(.rounded(16, .bold))
                            .foregroundStyle(e.amount >= 0 ? pal.text : pal.minus)
                        if !e.note.isEmpty {
                            Text(e.note).font(.rounded(13)).foregroundStyle(pal.sub).lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(Fmt.ago(e.date)).font(.rounded(13)).foregroundStyle(pal.sub)
                    Button { withAnimation { model.deleteEntry(e) } } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(pal.sub)
                            .padding(6)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func widgetCard(_ pal: Palette) -> some View {
        card("Виджет", pal) {
            Text("Зажми виджет на главном экране → «Изменить виджет» → выбери копилку и оформление. Если копилка не выбрана, показывается главная ★.")
                .font(.rounded(14)).foregroundStyle(pal.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
            if !Store.isShared {
                Text("⚠️ Виджет пока не видит данные приложения. Переустанови приложение через AltStore — он настроит общую папку.")
                    .font(.rounded(13, .semibold)).foregroundStyle(pal.minus)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
            }
        }
    }

    private func appearanceCard(_ pal: Palette) -> some View {
        card("Оформление", pal) {
            Text("Приложение").font(.rounded(16)).foregroundStyle(pal.text).padding(.vertical, 6)
            themePicker(selection: model.data.appTheme, pal: pal) { t in
                withAnimation(.easeInOut(duration: 0.3)) { model.setAppTheme(t) }
            }
            Text("Виджеты по умолчанию").font(.rounded(16)).foregroundStyle(pal.text).padding(.top, 12).padding(.bottom, 6)
            themePicker(selection: model.data.widgetTheme, pal: pal) { model.setWidgetTheme($0) }
            Text("У каждого виджета можно выбрать своё оформление в его настройках.")
                .font(.rounded(13)).foregroundStyle(pal.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 10)
            Divider().overlay(pal.line)
            Button { withAnimation { model.importFromClipboard() } } label: {
                Label("Перенести копилки из Scriptable", systemImage: "square.and.arrow.down")
                    .font(.rounded(16, .semibold)).foregroundStyle(pal.pink)
            }
            .padding(.vertical, 12)
        }
    }

    private func themePicker(selection: ThemeChoice, pal: Palette, onPick: @escaping (ThemeChoice) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(ThemeChoice.allCases) { t in
                let on = t == selection
                Button { onPick(t) } label: {
                    Text(t.title).font(.rounded(14, .bold))
                        .foregroundStyle(on ? pal.text : pal.sub)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 11).fill(on ? pal.bg : Color.clear)
                            .shadow(color: .black.opacity(on ? 0.15 : 0), radius: 2, y: 1))
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14).fill(pal.track))
    }

    private func piggyCard(_ pal: Palette) -> some View {
        card("Копилка", pal) {
            Button { sheet = .edit } label: {
                Label("Изменить название и цель", systemImage: "pencil")
                    .font(.rounded(16, .semibold)).foregroundStyle(pal.pink)
            }
            .padding(.vertical, 12)
            Divider().overlay(pal.line)
            Button { confirmDelete = true } label: {
                Label("Удалить копилку", systemImage: "trash")
                    .font(.rounded(16, .semibold)).foregroundStyle(pal.minus)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Пусто

    private func emptyState(_ pal: Palette) -> some View {
        VStack(spacing: 14) {
            Image(Pig.imageName(0, dark: dark)).resizable().scaledToFit().frame(maxWidth: 320)
            Text("Пока нет копилок").font(.rounded(25, .heavy)).foregroundStyle(pal.text)
            Text("Создай первую — на отпуск, подарок или что угодно ещё.")
                .font(.rounded(16)).foregroundStyle(pal.sub).multilineTextAlignment(.center)
            Button { sheet = .create } label: {
                Text("Создать копилку").font(.rounded(17, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(pal.pink))
            }
            Button("Перенести копилки из Scriptable") { withAnimation { model.importFromClipboard() } }
                .font(.rounded(15, .semibold)).foregroundStyle(pal.pink)
            Text("Сначала открой копилку в Scriptable и нажми «Экспорт» — данные скопируются, затем нажми кнопку выше.")
                .font(.rounded(13)).foregroundStyle(pal.sub).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
        .padding(.top, 10)
    }
}
