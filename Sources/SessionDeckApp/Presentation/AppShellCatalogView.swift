import SessionDeckCore
import SwiftUI

struct AppShellCatalogView: View {
    let summary: AppShellCatalogSummary
    let refreshState: AppShellRefreshState
    @Binding var selectedSessionID: SessionID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Catalog", systemImage: "list.bullet.rectangle")
                    .font(.title3.bold())

                Spacer()

                Text(countSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Label(summary.statusMessage, systemImage: statusIcon)
                .font(.callout)
                .foregroundStyle(statusColor)

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
                header

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

    private var header: some View {
        HStack(spacing: 12) {
            Text("Session")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Source")
                .frame(width: 150, alignment: .leading)
            Text("Project")
                .frame(width: 150, alignment: .leading)
            Text("Activity")
                .frame(width: 140, alignment: .leading)
            Text("Size")
                .frame(width: 70, alignment: .trailing)
            Text("Status")
                .frame(width: 120, alignment: .leading)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func rowView(_ row: AppShellCatalogRow) -> some View {
        VStack(spacing: 0) {
            Button(action: { selectedSessionID = row.id }) {
                HStack(spacing: 12) {
                    rowTitle(row)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(row.sourceLabel)
                        .frame(width: 150, alignment: .leading)
                    Text(row.projectHint)
                        .frame(width: 150, alignment: .leading)
                    Text(row.lastActivityLabel)
                        .frame(width: 140, alignment: .leading)
                    Text(row.sizeLabel)
                        .frame(width: 70, alignment: .trailing)

                    Label(row.statusLabel, systemImage: severityIcon(row.severity))
                        .labelStyle(.titleAndIcon)
                        .frame(width: 120, alignment: .leading)
                        .foregroundStyle(severityColor(row.severity))
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
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
                .lineLimit(1)

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
        if summary.sourceFailureCount > 0 {
            return "xmark.octagon"
        }
        if summary.diagnosticCount > 0 || summary.sourceWarningCount > 0 {
            return "exclamationmark.triangle"
        }
        if summary.totalCount == 0 {
            return "tray"
        }

        return "checkmark.circle"
    }

    private var statusColor: Color {
        if summary.sourceFailureCount > 0 {
            return .red
        }
        if summary.diagnosticCount > 0 || summary.sourceWarningCount > 0 {
            return .orange
        }

        return .secondary
    }

    private var emptyMessage: String {
        summary.sourceFailureCount > 0 ? "Catalog source failed" : "No catalog rows"
    }

    private var emptyDetail: String {
        summary.sourceFailureCount > 0
            ? "Source diagnostics are available above; no rows were hidden."
            : "No lightweight session metadata is available from configured sources yet."
    }

    private var emptyIcon: String {
        summary.sourceFailureCount > 0 ? "xmark.octagon" : "tray"
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
