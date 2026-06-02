import SessionDeckCore
import SwiftUI

@main
struct SessionDeckApp: App {
    var body: some Scene {
        WindowGroup {
            AppShellView(viewModel: SessionDeckCompositionRoot.makeAppShellViewModel())
        }
        .windowResizability(.contentSize)
    }
}
