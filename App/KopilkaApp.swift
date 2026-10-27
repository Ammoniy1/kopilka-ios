import SwiftUI

@main
struct KopilkaApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .onOpenURL { model.handle(url: $0) }
        }
    }
}
