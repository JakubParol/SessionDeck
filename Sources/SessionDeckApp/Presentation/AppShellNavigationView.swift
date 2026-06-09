import SessionDeckCore
import SwiftUI

struct AppShellNavigationView: View {
    let summary: AppShellNavigationSummary
    @Binding var selectedNavigationNodeID: String?

    var body: some View {
        List(selection: $selectedNavigationNodeID) {
            ForEach(summary.sectionNodes) { sectionNode in
                Section {
                    navigationRow(sectionNode, level: 0)

                    ForEach(flattenedChildren(of: sectionNode)) { row in
                        navigationRow(row.node, level: row.level)
                    }
                } header: {
                    Text(sectionNode.title)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Navigation")
    }

    private func navigationRow(_ node: AppShellNavigationNode, level: Int) -> some View {
        Label {
            nodeText(node)
        } icon: {
            Image(systemName: level == 0 ? sectionIcon(node) : childIcon(node))
        }
        .padding(.leading, CGFloat(level) * 12)
        .tag(node.id)
    }

    private func nodeText(_ node: AppShellNavigationNode) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(node.title)
                .lineLimit(1)
            Text(node.countLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func flattenedChildren(of node: AppShellNavigationNode) -> [NavigationSidebarRow] {
        flattenedRows(nodes: node.children, level: 1)
    }

    private func flattenedRows(nodes: [AppShellNavigationNode], level: Int) -> [NavigationSidebarRow] {
        nodes.flatMap { childNode in
            [NavigationSidebarRow(node: childNode, level: level)]
                + flattenedRows(nodes: childNode.children, level: level + 1)
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
            return "exclamationmark.triangle"
        case nil:
            if node.id.contains(".thread.") {
                return node.children.isEmpty ? "bubble.left" : "bubble.left.and.bubble.right"
            }
            return "folder"
        }
    }
}

private struct NavigationSidebarRow: Identifiable {
    let node: AppShellNavigationNode
    let level: Int

    var id: String {
        node.id
    }
}
