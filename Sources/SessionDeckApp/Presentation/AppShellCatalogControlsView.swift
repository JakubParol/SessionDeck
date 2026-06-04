import SessionDeckCore
import SwiftUI

struct AppShellCatalogControlsView: View {
    let controls: AppShellCatalogQueryControls
    @Binding var queryState: AppShellCatalogQueryState
    let onQueryChange: (AppShellCatalogQueryState) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Search", systemImage: "magnifyingglass")
                    .labelStyle(.iconOnly)

                TextField("Catalog metadata", text: searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180)

                filterPicker(
                    title: "Project",
                    systemImage: "folder",
                    selection: projectSelection,
                    options: controls.options.projectOptions
                )

                filterPicker(
                    title: "Source",
                    systemImage: "externaldrive",
                    selection: sourceSelection,
                    options: controls.options.sourceOptions
                )

                filterPicker(
                    title: "Profile",
                    systemImage: "person.crop.circle",
                    selection: profileSelection,
                    options: controls.options.profileOptions
                )

                parseStatusMenu

                if controls.hasActiveFilters {
                    Button(action: clearFilters) {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                }
            }

            if controls.activeFilters.isEmpty == false {
                activeFilterLabels
            }
        }
    }

    private var activeFilterLabels: some View {
        HStack(spacing: 6) {
            ForEach(controls.activeFilters) { filter in
                Button(action: { clear(filter) }) {
                    Label(filter.title, systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var parseStatusMenu: some View {
        Menu {
            ForEach(controls.options.parseStatusOptions) { option in
                Button(action: { toggleParseStatus(option.id) }) {
                    Label(
                        option.menuTitle,
                        systemImage: queryState.selectedParseStatusOptionIDs.contains(option.id)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
            }
        } label: {
            Label(parseStatusTitle, systemImage: "waveform.path.ecg")
        }
        .disabled(controls.options.parseStatusOptions.isEmpty)
    }

    private func filterPicker(
        title: String,
        systemImage: String,
        selection: Binding<String>,
        options: [AppShellCatalogFilterOption]
    ) -> some View {
        Picker(selection: selection) {
            Text("All \(title.lowercased())")
                .tag("")
            ForEach(options) { option in
                Text(option.menuTitle)
                    .tag(option.id)
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .frame(width: 150)
        .disabled(options.isEmpty)
    }

    private var searchText: Binding<String> {
        Binding(
            get: { queryState.searchText },
            set: { update(queryState.replacing(searchText: $0)) }
        )
    }

    private var projectSelection: Binding<String> {
        Binding(
            get: { queryState.selectedProjectOptionID ?? "" },
            set: { update(queryState.replacing(projectOptionID: $0.emptyAsNil)) }
        )
    }

    private var sourceSelection: Binding<String> {
        Binding(
            get: { queryState.selectedSourceOptionID ?? "" },
            set: { update(queryState.replacing(sourceOptionID: $0.emptyAsNil)) }
        )
    }

    private var profileSelection: Binding<String> {
        Binding(
            get: { queryState.selectedProfileOptionID ?? "" },
            set: { update(queryState.replacing(profileOptionID: $0.emptyAsNil)) }
        )
    }

    private var parseStatusTitle: String {
        let count = queryState.selectedParseStatusOptionIDs.count
        return count == 0 ? "Status" : "Status \(count)"
    }

    private func toggleParseStatus(_ optionID: String) {
        var selected = queryState.selectedParseStatusOptionIDs
        if selected.contains(optionID) {
            selected.remove(optionID)
        } else {
            selected.insert(optionID)
        }
        update(queryState.replacing(parseStatusOptionIDs: selected))
    }

    private func clearFilters() {
        update(queryState.cleared())
    }

    private func clear(_ filter: AppShellCatalogActiveFilter) {
        update(queryState.clearing(activeFilter: filter))
    }

    private func update(_ nextState: AppShellCatalogQueryState) {
        queryState = nextState
        onQueryChange(nextState)
    }
}

private extension String {
    var emptyAsNil: String? {
        isEmpty ? nil : self
    }
}
