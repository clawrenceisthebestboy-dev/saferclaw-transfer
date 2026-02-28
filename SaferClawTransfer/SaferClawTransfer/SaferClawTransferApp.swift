import SwiftUI

@main
struct SaferClawTransferApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 580)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 580)
    }
}
