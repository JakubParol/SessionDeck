import SessionDeckCore
import SwiftUI

struct AppShellView: View {
    let viewModel: AppShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.title)
                .font(.largeTitle.bold())

            Text(viewModel.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label(viewModel.statusMessage, systemImage: "sparkles.rectangle.stack")
                Label("Configured session sources: \(viewModel.configuredSourceCount)", systemImage: "folder.badge.questionmark")
                Label(safetySummary, systemImage: "lock.shield")
            }
            .font(.body)
        }
        .padding(32)
        .frame(minWidth: 560, minHeight: 320, alignment: .leading)
    }

    private var safetySummary: String {
        if viewModel.safetyPolicy.readsRealAgentStores
            || viewModel.safetyPolicy.permitsNetworkCalls
            || viewModel.safetyPolicy.permitsCommandExecution
            || viewModel.safetyPolicy.permitsSessionMutation {
            return "Safety policy is not placeholder-safe."
        }

        return "Placeholder launch performs no local store reads, network calls, commands, or session mutations."
    }
}
