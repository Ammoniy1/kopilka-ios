import SwiftUI

private struct SheetField: ViewModifier {
    let pal: Palette
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(pal.card))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(pal.line))
            .foregroundStyle(pal.text)
    }
}

private extension View {
    func sheetField(_ pal: Palette) -> some View { modifier(SheetField(pal: pal)) }
}

private struct SheetButtons: View {
    let pal: Palette
    let okTitle: String
    var okColor: Color? = nil
    let onCancel: () -> Void
    let onOK: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onCancel) {
                Text("Отмена").font(.rounded(17, .bold)).foregroundStyle(pal.text)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(pal.card))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(pal.line))
            }
            Button(action: onOK) {
                Text(okTitle).font(.rounded(17, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(okColor ?? pal.pink))
            }
        }
    }
}

/// Пополнить / снять
struct AmountSheet: View {
    let sign: Int
    let pal: Palette
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sign > 0 ? "Пополнить" : "Снять").font(.rounded(22, .heavy)).foregroundStyle(pal.text)
            TextField("0 \(model.currency)", text: $amount)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.rounded(34, .heavy))
                .focused($focused)
                .sheetField(pal)
            TextField("Комментарий (необязательно)", text: $note)
                .font(.rounded(17))
                .sheetField(pal)
            if let p = model.selected {
                Text("Сейчас в копилке \(Fmt.money(p.saved, model.currency))")
                    .font(.rounded(13)).foregroundStyle(pal.sub)
            }
            SheetButtons(pal: pal, okTitle: sign > 0 ? "Положить" : "Снять",
                         onCancel: { dismiss() },
                         onOK: save)
            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.height(360)])
        .presentationBackground(pal.bg)
        .presentationCornerRadius(24)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true } }
    }

    private func save() {
        guard let v = Fmt.parse(amount), v > 0 else { focused = true; return }
        let n = note.trimmingCharacters(in: .whitespaces)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { model.change(by: Double(sign) * v, note: n) }
        }
    }
}

/// Новая копилка / изменить копилку
struct EditSheet: View {
    let isNew: Bool
    let pal: Palette
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var target = ""
    @State private var start = ""
    @State private var emoji = "🐷"
    @State private var error = ""

    private let emojis = ["🐷", "✈️", "🏖️", "🎁", "🏠", "🚗", "💻", "📱", "🎓", "💍", "🎮", "🐶", "👟", "💰"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(isNew ? "Новая копилка" : "Изменить копилку").font(.rounded(22, .heavy)).foregroundStyle(pal.text)

                label("Название")
                TextField("Например, Отпуск", text: $name).font(.rounded(17)).sheetField(pal)

                label("Сколько нужно накопить, \(model.currency)")
                TextField("5000", text: $target).keyboardType(.decimalPad).font(.rounded(17)).sheetField(pal)

                if isNew {
                    label("Уже накоплено (необязательно)")
                    TextField("0", text: $start).keyboardType(.decimalPad).font(.rounded(17)).sheetField(pal)
                }

                label("Значок")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(emojis, id: \.self) { e in
                        Button { emoji = e } label: {
                            Text(e).font(.system(size: 24))
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 10).fill(pal.card))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(e == emoji ? pal.pink : Color.clear, lineWidth: 2))
                        }
                    }
                }

                if !error.isEmpty {
                    Text(error).font(.rounded(14, .semibold)).foregroundStyle(pal.minus)
                }

                SheetButtons(pal: pal, okTitle: "Сохранить", onCancel: { dismiss() }, onOK: save)
                    .padding(.top, 6)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationBackground(pal.bg)
        .presentationCornerRadius(24)
        .onAppear {
            if !isNew, let p = model.selected {
                name = p.name
                emoji = p.emoji
                target = Fmt.money(p.target, "").trimmingCharacters(in: .whitespaces)
            }
        }
    }

    private func label(_ s: String) -> some View {
        Text(s).font(.rounded(13, .semibold)).foregroundStyle(pal.sub).padding(.leading, 4).padding(.top, 2)
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = "Впиши название"; return }
        guard let t = Fmt.parse(target), t > 0 else { error = "Сумма цели должна быть больше нуля"; return }
        if isNew {
            model.create(name: n, emoji: emoji, target: t, start: Fmt.parse(start))
        } else {
            model.update(name: n, emoji: emoji, target: t)
        }
        dismiss()
    }
}
