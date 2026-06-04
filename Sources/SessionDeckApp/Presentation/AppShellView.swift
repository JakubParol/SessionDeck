import SessionDeckCore
import SwiftUI

struct AppShellView: View {
    let appShellUseCase: AppShellUseCase
    @State private var viewModel: AppShellViewModel
    @State private var selectedSessionID: SessionID?

    init(viewModel: AppShellViewModel, appShellUseCase: AppShellUseCase) {
        self.appShellUseCase = appShellUseCase
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.title)
                    .font(.largeTitle.bold())

                Spacer()

                Button(action: refreshSources) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.refreshState == .refreshing)
            }

            Text(viewModel.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label(viewModel.statusMessage, systemImage: "sparkles.rectangle.stack")
                Label(viewModel.sourceDiscoverySummary.statusMessage, systemImage: sourceStatusIcon)
                Label(sourceCountSummary, systemImage: "folder.badge.questionmark")
                Label(candidateCountSummary, systemImage: "doc.text.magnifyingglass")
                Label(diagnosticCountSummary, systemImage: "exclamationmark.triangle")
                Label(safetySummary, systemImage: "lock.shield")
            }
            .font(.body)

            Divider()

            AppShellCatalogView(
                summary: viewModel.catalogSummary,
                refreshState: viewModel.refreshState,
                selectedSessionID: $selectedSessionID
            )
        }
        .padding(32)
        .frame(minWidth: 760, minHeight: 520, alignment: .leading)
    }

    private var sourceCountSummary: String {
        let summary = viewModel.sourceDiscoverySummary
        return "Sources: \(summary.availableSourceCount) available of \(summary.configuredSourceCount) configured."
    }

    private var candidateCountSummary: String {
        guard let candidateFileCount = viewModel.sourceDiscoverySummary.candidateFileCount else {
            return "Candidate transcripts: not checked yet."
        }

        return "Candidate transcripts: \(candidateFileCount)."
    }

    private var diagnosticCountSummary: String {
        let summary = viewModel.sourceDiscoverySummary
        return "Diagnostics: \(summary.warningCount) warning(s), \(summary.errorCount) error(s)."
    }

    private var sourceStatusIcon: String {
        let summary = viewModel.sourceDiscoverySummary
        if summary.errorCount > 0 {
            return "xmark.octagon"
        }
        if summary.warningCount > 0 || summary.availableSourceCount == 0 {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle"
    }

    private var safetySummary: String {
        if viewModel.safetyPolicy.permitsNetworkCalls
            || viewModel.safetyPolicy.permitsCommandExecution
            || viewModel.safetyPolicy.permitsSessionMutation {
            return "Safety policy allows behavior beyond read-only local discovery."
        }

        if viewModel.safetyPolicy.readsRealAgentStores {
            return "Reads configured local agent stores only; no network, commands, uploads, or session mutations."
        }

        return "No local store reads, network calls, commands, uploads, or session mutations."
    }

    private func refreshSources() {
        viewModel = appShellUseCase.refreshingViewModel()
        viewModel = appShellUseCase.refreshViewModel()
    }
}
