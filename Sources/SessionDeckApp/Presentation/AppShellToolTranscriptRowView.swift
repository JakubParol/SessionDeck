import SessionDeckCore
import SwiftUI

struct AppShellToolTranscriptRowView: View {
    let row: AppShellTranscriptSegmentRow
    let presentation: AppShellTranscriptToolPresentation
    @Binding var expandedToolRowIDs: Set<String>

    var body: some View {
        DisclosureGroup(
            isExpanded: expansionBinding,
            content: {
                expandedContent
            },
            label: {
                label
            }
        )
        .disclosureGroupStyle(.automatic)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(rowBorderColor)
        )
        .accessibilityLabel("\(row.text), \(presentation.metadataSummary), \(presentation.detailSummary)")
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if presentation.detailSummary.isEmpty == false {
                Text(presentation.detailSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if presentation.diagnosticMessages.isEmpty == false {
                ForEach(presentation.diagnosticMessages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text(presentation.expandedText)
                .font(.body.monospaced())
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.top, 6)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(row.text)
                    .font(.caption.bold())
                    .foregroundStyle(roleLabelColor)

                if let timestampLabel = row.timestampLabel {
                    Text(timestampLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(presentation.metadataSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var expansionBinding: Binding<Bool> {
        Binding(
            get: {
                expandedToolRowIDs.contains(row.id)
            },
            set: { isExpanded in
                if isExpanded {
                    expandedToolRowIDs.insert(row.id)
                } else {
                    expandedToolRowIDs.remove(row.id)
                }
            }
        )
    }

    private var roleLabelColor: Color {
        severityColor(row.severity)
    }

    private var rowBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    private var rowBorderColor: Color {
        severityColor(row.severity).opacity(0.35)
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
}
