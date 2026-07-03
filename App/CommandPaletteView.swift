import SwiftUI
import AppKit

/// Spotlight-style command palette overlay (⌘K): fuzzy search across
/// containers, images, volumes, networks, and global actions.
///
/// Keyboard handling uses a local `NSEvent` monitor while visible because a
/// focused `TextField` swallows arrow keys before `onKeyPress` on an ancestor
/// can see them. The four navigation keys are consumed; everything else flows
/// through to the search field.
struct CommandPaletteView: View {
    @Environment(AppModel.self) private var app

    @State private var query = ""
    @State private var selection = 0
    @State private var keyMonitor: Any?
    @FocusState private var searchFocused: Bool

    /// Snapshot taken on open (and once more after the on-demand index fetch),
    /// deliberately NOT live: the 5s background poll must not reshuffle
    /// results under the user's cursor.
    @State private var items: [PaletteItem] = []

    private var results: [PaletteItem] {
        PaletteRanker.rank(items, query: query)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Dim backdrop; click anywhere outside to dismiss.
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { app.paletteVisible = false }

            palette
                .frame(width: 520)
                .padding(.top, 100)
        }
        .task {
            searchFocused = true
            items = app.paletteItems
            await app.refreshPaletteIndex()
            items = app.paletteItems
        }
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
        .onChange(of: query) { selection = 0 }
    }

    private var palette: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.5)
            // Fixed height: the card must not resize with every keystroke.
            Group {
                if results.isEmpty {
                    Text("No matches")
                        .font(Theme.Typography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    resultsList
                }
            }
            .frame(height: 336)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous)
                .strokeBorder(Theme.Palette.borderGradient, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search containers, images, actions…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($searchFocused)
            Text("esc")
                .font(Theme.Typography.monoCaption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Theme.Palette.controlBackground, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                        PaletteRow(
                            item: item,
                            isSelected: index == selection,
                            showCategory: categoryLabel(at: index)
                        )
                        .id(index)
                        .onTapGesture { activate(item) }
                    }
                }
                .padding(6)
            }
            .onChange(of: selection) {
                proxy.scrollTo(selection)
            }
        }
    }

    /// Shows a category header above the first item of each category run.
    private func categoryLabel(at index: Int) -> String? {
        let category = results[index].category
        guard index == 0 || results[index - 1].category != category else { return nil }
        return category.label
    }

    // MARK: Activation & keyboard

    private func activate(_ item: PaletteItem) {
        app.dispatch(item.intent)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // The monitor outlives dismissal by the transition's duration, and
            // sheets get their own key window — in both cases the keys belong
            // to someone else.
            guard app.paletteVisible, event.window?.isSheet != true else { return event }
            switch event.keyCode {
            case 125:  // ↓
                selection = min(selection + 1, max(results.count - 1, 0))
                return nil
            case 126:  // ↑
                selection = max(selection - 1, 0)
                return nil
            case 36, 76:  // return / keypad-enter
                if results.indices.contains(selection) { activate(results[selection]) }
                return nil
            case 53:  // escape
                app.paletteVisible = false
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}

/// One result row.
private struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool
    let showCategory: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let showCategory {
                Text(showCategory.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
            }
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.22) : Theme.Palette.controlBackground)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(Theme.Typography.body)
                        .lineLimit(1)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.monoCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isSelected ? Color.accentColor.opacity(0.13) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
    }
}
