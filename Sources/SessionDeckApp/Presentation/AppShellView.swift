import SessionDeckCore
import SwiftUI

struct AppShellView: View {
    let appShellUseCase: AppShellUseCase
    @State private var viewModel: AppShellViewModel
    @State private var selectedNavigationNodeID: String?
    @State private var selectedSessionID: SessionID?
    @State private var catalogQueryState: AppShellCatalogQueryState

    init(viewModel: AppShellViewModel, appShellUseCase: AppShellUseCase) {
        self.appShellUseCase = appShellUseCase
        self._viewModel = State(initialValue: viewModel)
        self._selectedNavigationNodeID = State(initialValue: viewModel.selectedNavigationNodeID)
        self._catalogQueryState = State(initialValue: viewModel.catalogQueryControls.queryState)
    }

    var body: some View {
        NavigationSplitView {
            AppShellNavigationView(
                summary: viewModel.navigationSummary,
                selectedNavigationNodeID: $selectedNavigationNodeID
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detailContent
        }
        .frame(minWidth: 900, minHeight: 560)
        .onChange(of: selectedNavigationNodeID) { _, newValue in
            selectNavigationNode(newValue)
        }
        .onChange(of: selectedSessionID) { _, newValue in
            selectSession(newValue)
        }
    }

    private var detailContent: some View {
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

            sourceHealthRows

            Divider()

            readingSurface
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var readingSurface: some View {
        HStack(alignment: .top, spacing: 16) {
            AppShellCatalogView(
                summary: viewModel.catalogSummary,
                queryControls: viewModel.catalogQueryControls,
                refreshState: viewModel.refreshState,
                scopeTitle: viewModel.readingSurface.catalogTitle,
                catalogQueryState: $catalogQueryState,
                selectedSessionID: $selectedSessionID,
                onCatalogQueryChange: updateCatalogQuery
            )
            .frame(
                minWidth: viewModel.readingSurface.minimumCatalogPaneWidth,
                maxWidth: 460,
                maxHeight: .infinity,
                alignment: .topLeading
            )

            Divider()

            AppShellTranscriptDetailView(state: viewModel.selectedTranscriptDetail)
                .frame(
                    minWidth: viewModel.readingSurface.minimumTranscriptPaneWidth,
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var sourceHealthRows: some View {
        if viewModel.sourceDiscoverySummary.sourceHealthRows.isEmpty == false {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.sourceDiscoverySummary.sourceHealthRows, id: \.id) { row in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: sourceHealthIcon(for: row.severity))
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(row.statusLabel)
                                    .font(.subheadline.weight(.semibold))
                                Text(row.title)
                                    .font(.subheadline)
                            }

                            Text(row.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(row.location)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
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

    private func sourceHealthIcon(for severity: AppShellSourceHealthSeverity) -> String {
        switch severity {
        case .healthy:
            return "checkmark.circle"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
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
        let previousSelectedTranscriptDetail = viewModel.selectedTranscriptDetail
        viewModel = appShellUseCase.refreshingViewModel(
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQueryState,
            selectedSessionID: selectedSessionID,
            previousSelectedTranscriptDetail: previousSelectedTranscriptDetail
        )
        let refreshedViewModel = appShellUseCase.refreshViewModel(
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQueryState,
            selectedSessionID: selectedSessionID,
            previousSelectedTranscriptDetail: previousSelectedTranscriptDetail
        )
        apply(refreshedViewModel)
    }

    private func selectNavigationNode(_ nodeID: String?) {
        let selectedViewModel = appShellUseCase.makeViewModel(
            selectedNavigationNodeID: nodeID,
            catalogQuery: catalogQueryState,
            selectedSessionID: selectedSessionID
        )
        apply(selectedViewModel)
    }

    private func updateCatalogQuery(_ queryState: AppShellCatalogQueryState) {
        let queriedViewModel = appShellUseCase.makeViewModel(
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: queryState,
            selectedSessionID: selectedSessionID
        )
        apply(queriedViewModel)
    }

    private func selectSession(_ sessionID: SessionID?) {
        let selectedViewModel = appShellUseCase.makeViewModel(
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQueryState,
            selectedSessionID: sessionID
        )
        apply(selectedViewModel)
    }

    private func apply(_ updatedViewModel: AppShellViewModel) {
        selectedNavigationNodeID = updatedViewModel.selectedNavigationNodeID
        selectedSessionID = selectedSessionID(in: updatedViewModel)
        catalogQueryState = updatedViewModel.catalogQueryControls.queryState
        viewModel = updatedViewModel
    }

    private func selectedSessionID(in updatedViewModel: AppShellViewModel) -> SessionID? {
        let rowIDs = Set(updatedViewModel.catalogSummary.rows.map(\.id))
        if let selectedSessionID, rowIDs.contains(selectedSessionID) {
            return selectedSessionID
        }

        return updatedViewModel.catalogSummary.rows.first?.id
    }
}
