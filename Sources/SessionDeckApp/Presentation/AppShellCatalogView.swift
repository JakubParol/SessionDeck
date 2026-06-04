import SessionDeckCore
import SwiftUI

struct AppShellCatalogView: View {
    let summary: AppShellCatalogSummary
    let queryControls: AppShellCatalogQueryControls
    let refreshState: AppShellRefreshState
    let scopeTitle: String
    @Binding var catalogQueryState: AppShellCatalogQueryState
    @Binding var selectedSessionID: SessionID?
    let onCatalogQueryChange: (AppShellCatalogQueryState) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(scopeTitle, systemImage: "list.bullet.rectangle")
                    .font(.title3.bold())

                Spacer()

                Text(countSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(summary.statusMessage, systemImage: statusIcon)
                .font(.callout)
                .foregroundStyle(statusColor)

            AppShellCatalogControlsView(
                controls: queryControls,
                queryState: $catalogQueryState,
                onQueryChange: onCatalogQueryChange
            )

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if refreshState == .refreshing {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing catalog...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
        } else if summary.rows.isEmpty {
            emptyState
        } else {
            rowList
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(emptyMessage, systemImage: emptyIcon)
                .font(.headline)
            Text(emptyDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
    }

    private var rowList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(summary.rows) { row in
                    rowView(row)
                }
            }
        }
        .frame(minHeight: 220)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor))
        )
    }

    private func rowView(_ row: AppShellCatalogRow) -> some View {
        VStack(spacing: 0) {
            Button(action: { selectedSessionID = row.id }) {
                VStack(alignment: .leading, spacing: 6) {
                    rowTitle(row)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(row.sourceLabel) / \(row.projectHint)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 10) {
                        Text(row.lastActivityLabel)
                            .lineLimit(1)
                        Text(row.sizeLabel)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Label(row.statusLabel, systemImage: severityIcon(row.severity))
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(severityColor(row.severity))
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .background(rowBackground(row))
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 12)
        }
    }

    private func rowTitle(_ row: AppShellCatalogRow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.title)
                .font(.body.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let diagnosticSummary = row.diagnosticSummary {
                Text(diagnosticSummary)
                    .font(.caption)
                    .foregroundStyle(severityColor(row.severity))
                    .lineLimit(1)
            }
        }
    }

    private var countSummary: String {
        "\(rowCountLabel(summary.totalCount)), \(diagnosticCountLabel(summary.diagnosticCount))."
    }

    private var statusIcon: String {
        switch summary.resultState {
        case .failure:
            return "xmark.octagon"
        case .warning:
            return "exclamationmark.triangle"
        case .noMatches:
            return "magnifyingglass"
        case .notRun, .empty:
            return "tray"
        case .matches:
            return "checkmark.circle"
        }
    }

    private var statusColor: Color {
        switch summary.resultState {
        case .failure:
            return .red
        case .warning:
            return .orange
        case .matches, .empty, .noMatches, .notRun:
            return .secondary
        }
    }

    private var emptyMessage: String {
        summary.emptyState?.title ?? "No catalog rows"
    }

    private var emptyDetail: String {
        summary.emptyState?.detail ?? "No lightweight session metadata is available from configured sources yet."
    }

    private var emptyIcon: String {
        switch summary.resultState {
        case .failure:
            return "xmark.octagon"
        case .noMatches:
            return "magnifyingglass"
        case .notRun, .empty, .matches, .warning:
            return "tray"
        }
    }

    private func rowBackground(_ row: AppShellCatalogRow) -> Color {
        if selectedSessionID == row.id {
            return Color.accentColor.opacity(0.12)
        }
        if row.severity == .error {
            return Color.red.opacity(0.05)
        }
        if row.severity == .warning {
            return Color.orange.opacity(0.05)
        }

        return .clear
    }

    private func severityIcon(_ severity: AppShellCatalogRowSeverity) -> String {
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

    private func severityColor(_ severity: AppShellCatalogRowSeverity) -> Color {
        switch severity {
        case .healthy:
            return .green
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func rowCountLabel(_ count: Int) -> String {
        count == 1 ? "1 row" : "\(count) rows"
    }

    private func diagnosticCountLabel(_ count: Int) -> String {
        count == 1 ? "1 diagnostic" : "\(count) diagnostics"
    }
}
