import SwiftUI
import UIKit
import WidgetKit
import Observation

@Observable
final class AppModel {
    var data: AppData
    var selectedID: UUID?
    var toast: ToastMessage?
    var celebrate = 0          // меняется, когда цель достигнута
    var coinDrops = 0          // меняется при каждом пополнении (анимация монетки)
    private var undoSnapshot: (data: AppData, selected: UUID?)?

    init() {
        data = Store.load()
        selectedID = data.mainPiggy?.id
    }

    var selected: Piggy? { data.piggy(selectedID) ?? data.mainPiggy }
    var currency: String { data.currency }

    private func index(_ id: UUID?) -> Int? {
        guard let id else { return nil }
        return data.piggies.firstIndex { $0.id == id }
    }

    // MARK: сохранение

    private func commit() {
        Store.save(data)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func snapshot() { undoSnapshot = (data, selectedID) }

    func undo() {
        guard let s = undoSnapshot else { return }
        data = s.data
        selectedID = s.selected
        undoSnapshot = nil
        toast = nil
        commit()
    }

    func reloadFromDisk() {
        data = Store.load()
        if data.piggy(selectedID) == nil { selectedID = data.mainPiggy?.id }
    }

    // MARK: деньги

    func change(by amount: Double, note: String = "") {
        guard let i = index(selected?.id) else { return }
        let before = data.piggies[i].progress
        let real = amount < 0 ? -min(-amount, data.piggies[i].saved) : amount
        guard real != 0 else { return }
        snapshot()
        data.piggies[i].saved = ((data.piggies[i].saved + real) * 100).rounded() / 100
        data.piggies[i].history.append(Entry(date: Date(), amount: real, note: note))
        if data.piggies[i].history.count > 300 { data.piggies[i].history.removeFirst(data.piggies[i].history.count - 300) }
        commit()
        if real > 0 { coinDrops += 1 }
        toast = ToastMessage(text: (real > 0 ? "+" : "−") + Fmt.money(abs(real), currency), undo: true)
        if before < 1 && data.piggies[i].progress >= 1 { celebrate += 1 }
    }

    func deleteEntry(_ e: Entry) {
        guard let i = index(selected?.id) else { return }
        snapshot()
        data.piggies[i].history.removeAll { $0.id == e.id }
        data.piggies[i].saved = max(0, ((data.piggies[i].saved - e.amount) * 100).rounded() / 100)
        commit()
        toast = ToastMessage(text: "Запись удалена", undo: true)
    }

    // MARK: копилки

    func create(name: String, emoji: String, target: Double, start: Double?) {
        snapshot()
        var p = Piggy(num: data.nextNum, name: name, emoji: emoji, target: target, saved: 0)
        if let start, start > 0 {
            p.saved = start
            p.history.append(Entry(date: Date(), amount: start, note: "начальная сумма"))
        }
        data.nextNum += 1
        data.piggies.append(p)
        if data.mainID == nil { data.mainID = p.id }
        selectedID = p.id
        commit()
    }

    func update(name: String, emoji: String, target: Double) {
        guard let i = index(selected?.id) else { return }
        snapshot()
        data.piggies[i].name = name
        data.piggies[i].emoji = emoji
        data.piggies[i].target = target
        commit()
    }

    func deleteSelected() {
        guard let i = index(selected?.id) else { return }
        snapshot()
        let id = data.piggies[i].id
        data.piggies.remove(at: i)
        if data.mainID == id { data.mainID = data.piggies.first?.id }
        selectedID = data.mainID
        commit()
        toast = ToastMessage(text: "Копилка удалена", undo: true)
    }

    func makeMain() {
        guard let p = selected else { return }
        data.mainID = p.id
        commit()
        toast = ToastMessage(text: "Теперь это главная копилка ★", undo: false)
    }

    // MARK: оформление

    func setAppTheme(_ t: ThemeChoice) {
        data.appTheme = t
        commit()
    }

    func cycleAppTheme() {
        let all = ThemeChoice.allCases
        let next = all[(all.firstIndex(of: data.appTheme)! + 1) % all.count]
        setAppTheme(next)
        toast = ToastMessage(text: next == .system ? "Как в системе" : next == .dark ? "Тёмное оформление 🌙" : "Светлое оформление ☀️", undo: false)
    }

    func setWidgetTheme(_ t: ThemeChoice) {
        data.widgetTheme = t
        commit()
        toast = ToastMessage(text: "Виджеты обновлены", undo: false)
    }

    // MARK: импорт

    func importFromClipboard() {
        guard let text = UIPasteboard.general.string,
              let imported = ScriptableImport.parse(text, into: data) else {
            toast = ToastMessage(text: "В буфере нет данных из Scriptable", undo: false)
            return
        }
        snapshot()
        let added = imported.piggies.count - data.piggies.count
        data = imported
        selectedID = data.mainPiggy?.id
        commit()
        toast = ToastMessage(text: "Перенесено копилок: \(added)", undo: true)
    }

    // MARK: ссылки из виджета: kopilka://piggy/<id>

    func handle(url: URL) {
        guard url.scheme == "kopilka" else { return }
        reloadFromDisk()
        if let id = UUID(uuidString: url.lastPathComponent), data.piggy(id) != nil {
            selectedID = id
        }
    }
}

struct ToastMessage: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let undo: Bool
}
