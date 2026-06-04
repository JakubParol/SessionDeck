import SessionDeckCore
import SwiftUI

struct AppShellNavigationView: View {
    let summary: AppShellNavigationSummary
    @Binding var selectedSessionID: SessionID?

    private let columns = [
        GridItem(.adaptive(minimum: 190), alignment: .topLeading),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Navigation", systemImage: "sidebar.left")
                .font(.title3.bold())

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(summary.sectionNodes) { sectionNode in
                    VStack(alignment: .leading, spacing: 6) {
                        nodeButton(sectionNode, systemImage: sectionIcon(sectionNode))

                        ForEach(sectionNode.children) { childNode in
                            VStack(alignment: .leading, spacing: 5) {
                                nodeButton(childNode, systemImage: childIcon(childNode))
                                    .padding(.leading, 18)

                                ForEach(childNode.children) { nestedNode in
                                    nodeButton(nestedNode, systemImage: childIcon(nestedNode))
                                        .padding(.leading, 36)
                                }
                            }
                        }
                    }
                }
            }
            .font(.callout)
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

    private func sectionIcon(_ node: AppShellNavigationNode) -> String {
        switch node.id {
        case "all-chats":
            return "bubble.left.and.bubble.right"
        case "projects":
            return "folder"
        case "non-project-chats":
            return "bubble.left"
        case "sources":
            return "externaldrive"
        case "recently-active":
            return "clock.arrow.circlepath"
        case "diagnostics":
            return "exclamationmark.triangle"
        default:
            return childIcon(node)
        }
    }

    private func childIcon(_ node: AppShellNavigationNode) -> String {
        switch node.problemCategory {
        case .missingPath, .unknownSource, .ambiguousProject:
            return "questionmark.folder"
        case .permissionDenied:
            return "lock.trianglebadge.exclamationmark"
        case .missingMetadata, .malformedMetadata, .parseWarning:
            return "doc.badge.exclamationmark"
        case nil:
            return node.children.isEmpty ? "folder" : "folder.badge.questionmark"
        }
    }
}
