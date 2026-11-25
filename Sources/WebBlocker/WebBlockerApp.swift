import SwiftUI

struct WebBlockerApp: App {
    @ViewState private var store = BlockStore()

    var body: some Scene {
        Window("WebBlocker", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 580, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 640, height: 780)
    }
}

/// The SDK declares `@State` as a macro whose plugin ships only with full Xcode.
/// This alias reaches the underlying property wrapper so the app builds with Command Line Tools alone.
typealias ViewState = SwiftUI.State
