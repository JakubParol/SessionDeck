import SessionDeckCore
import SwiftUI

struct AppShellDiagnosticsSummaryView: View {
    let summary: AppShellDiagnosticsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(summary.statusMessage, systemImage: icon(for: summary.severity))
                .foregroundStyle(color(for: summary.severity))

            ForEach(summary.rows) { row in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon(for: row.severity))
                        .foregroundStyle(color(for: row.severity))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(severityLabel(for: row.severity))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(color(for: row.severity))

                            Text(row.title)
                                .font(.subheadline.weight(.semibold))
                        }

                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(row.recoveryGuidance)
                            .font(.caption)

                        if let diagnosticCode = row.diagnosticCode {
                            Text(diagnosticCode)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        if let scopeLabel = row.scope.label {
                            Text(scopeLabel)
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

    private func severityLabel(for severity: AppShellDiagnosticSeverity) -> String {
        switch severity {
        case .healthy:
            return "Healthy"
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Blocking"
        }
    }

    private func icon(for severity: AppShellDiagnosticSeverity) -> String {
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

    private func color(for severity: AppShellDiagnosticSeverity) -> Color {
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
