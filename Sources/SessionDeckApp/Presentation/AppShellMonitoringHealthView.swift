import SessionDeckCore
import SwiftUI

struct AppShellMonitoringHealthView: View {
    let summary: AppShellMonitoringHealthSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(summary.statusMessage, systemImage: summaryIcon)
                .foregroundStyle(summaryColor)

            ForEach(summary.rows) { row in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon(for: row.severity))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))

                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let diagnosticCode = row.diagnosticCode {
                            Text(diagnosticCode)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var summaryIcon: String {
        icon(for: summary.severity)
    }

    private var summaryColor: Color {
        color(for: summary.severity)
    }

    private func icon(for severity: AppShellMonitoringHealthSeverity) -> String {
        switch severity {
        case .healthy:
            return "dot.radiowaves.left.and.right"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }

    private func color(for severity: AppShellMonitoringHealthSeverity) -> Color {
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
