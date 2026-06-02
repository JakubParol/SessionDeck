import SessionDeckCore
import SwiftUI

@main
struct SessionDeckApp: App {
    private let composition = SessionDeckCompositionRoot.makeApplicationComposition()

    var body: some Scene {
        WindowGroup {
            AppShellView(viewModel: composition.appShellViewModel)
        }
        .windowResizability(.contentSize)
    }
}
