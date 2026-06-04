import SessionDeckCore
import SwiftUI

struct AppShellTranscriptDetailView: View {
    let state: AppShellSelectedTranscriptDetailState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(state.title, systemImage: titleIcon)
                    .font(.title3.bold())
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if state.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Label(state.statusMessage, systemImage: statusIcon)
                .font(.callout)
                .foregroundStyle(statusColor)

            if state.metadataRows.isEmpty == false {
                metadataSection
            }

            if state.diagnosticMessages.isEmpty == false {
                diagnostics
            }

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            loadingState
        } else if state.rows.isEmpty {
            emptyState
        } else {
            transcriptRows
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(state.metadataRows) { row in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 86, alignment: .leading)

                    Text(row.value)
                        .font(.caption)
                        .foregroundStyle(row.isFallback ? .secondary : .primary)
                        .lineLimit(row.id == "path" ? 2 : 1)
                        .truncationMode(row.id == "path" ? .middle : .tail)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(state.diagnosticMessages, id: \.self) { message in
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Loading transcript...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(state.title, systemImage: titleIcon)
                .font(.headline)
            Text(state.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
    }

    private var transcriptRows: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(state.rows) { row in
                    transcriptRow(row)
                }
            }
            .padding(10)
        }
        .frame(minHeight: 220)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor))
        )
    }

    private func transcriptRow(_ row: AppShellTranscriptSegmentRow) -> some View {
        HStack {
            if row.roleStyle == .userTurn {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(row.roleLabel)
                        .font(.caption.bold())
                        .foregroundStyle(roleLabelColor(for: row))

                    if let timestampLabel = row.timestampLabel {
                        Text(timestampLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(row.text)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: row.roleStyle == .supporting ? .infinity : 680, alignment: .leading)
            .background(rowBackground(for: row))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(rowBorderColor(for: row))
            )

            if row.roleStyle == .assistantTurn {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleIcon: String {
        switch state.severity {
        case .healthy:
            return "text.bubble"
        case .info:
            return "doc.text.magnifyingglass"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }

    private var statusIcon: String {
        state.isLoading ? "arrow.clockwise" : titleIcon
    }

    private var statusColor: Color {
        severityColor(state.severity)
    }

    private func severityColor(_ severity: AppShellCatalogRowSeverity) -> Color {
        switch severity {
        case .healthy:
            return .secondary
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func roleLabelColor(for row: AppShellTranscriptSegmentRow) -> Color {
        switch row.roleStyle {
        case .userTurn:
            return .accentColor
        case .assistantTurn:
            return .primary
        case .supporting:
            return severityColor(row.severity)
        }
    }

    private func rowBackground(for row: AppShellTranscriptSegmentRow) -> Color {
        switch row.roleStyle {
        case .userTurn:
            return Color.accentColor.opacity(0.12)
        case .assistantTurn:
            return Color(nsColor: .controlBackgroundColor)
        case .supporting:
            return Color(nsColor: .textBackgroundColor)
        }
    }

    private func rowBorderColor(for row: AppShellTranscriptSegmentRow) -> Color {
        switch row.roleStyle {
        case .userTurn:
            return Color.accentColor.opacity(0.24)
        case .assistantTurn:
            return Color(nsColor: .separatorColor)
        case .supporting:
            return severityColor(row.severity).opacity(0.35)
        }
    }
}
