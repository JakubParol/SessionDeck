import SessionDeckCore
import SwiftUI

struct AppShellNavigationView: View {
    let summary: AppShellNavigationSummary
    @Binding var selectedSessionID: SessionID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Navigation", systemImage: "sidebar.left")
                .font(.title3.bold())

            HStack(alignment: .top, spacing: 20) {
                nodeButton(summary.allChatsNode, systemImage: "bubble.left.and.bubble.right")

                VStack(alignment: .leading, spacing: 7) {
                    nodeHeader(summary.diagnosticsNode, systemImage: "exclamationmark.triangle")

                    ForEach(summary.diagnosticsNode.children) { child in
                        VStack(alignment: .leading, spacing: 5) {
                            nodeButton(child, systemImage: "folder.badge.questionmark")
                                .padding(.leading, 18)

                            ForEach(child.children) { categoryNode in
                                nodeButton(categoryNode, systemImage: categoryIcon(categoryNode))
                                    .padding(.leading, 36)
                            }
                        }
                    }
                }
            }
            .font(.callout)
        }
    }

    private func nodeHeader(_ node: AppShellNavigationNode, systemImage: String) -> some View {
        Label {
            nodeText(node)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(node.count > 0 ? .orange : .secondary)
        }
    }

    private func nodeButton(_ node: AppShellNavigationNode, systemImage: String) -> some View {
        Button(action: { selectedSessionID = node.sessionIDs.first }) {
            Label {
                nodeText(node)
            } icon: {
                Image(systemName: systemImage)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(node.sessionIDs.isEmpty)
    }

    private func nodeText(_ node: AppShellNavigationNode) -> some View {
        HStack(spacing: 8) {
            Text(node.title)
                .lineLimit(1)
            Text(node.countLabel)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func categoryIcon(_ node: AppShellNavigationNode) -> String {
        switch node.problemCategory {
        case .missingPath, .unknownSource, .ambiguousProject:
            return "questionmark.folder"
        case .permissionDenied:
            return "lock.trianglebadge.exclamationmark"
        case .missingMetadata, .malformedMetadata, .parseWarning:
            return "doc.badge.exclamationmark"
        case nil:
            return "exclamationmark.triangle"
        }
    }
}
