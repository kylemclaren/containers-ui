import SwiftUI

struct NetworksScreen: View {
    @State private var model: NetworksViewModel
    @Environment(AppModel.self) private var app

    @State private var showCreate = false
    @State private var showPruneConfirm = false
    @State private var deleteTarget: ContainerNetwork?

    init(service: NetworkService) {
        _model = State(initialValue: NetworksViewModel(service: service))
    }

    var body: some View {
        @Bindable var model = model
        ScreenScaffold(title: "Networks", subtitle: model.subtitle) {
            SearchField(text: $model.searchText, prompt: "Search networks")
            CircleIconButton(systemImage: "arrow.clockwise", help: "Refresh") {
                Task { await model.load() }
            }
            PillButton { showPruneConfirm = true } label: {
                if model.isPruning {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Prune", systemImage: "sparkles")
                }
            }
            .disabled(model.isPruning || model.isLoading)
            PillButton(style: .accent) { showCreate = true } label: {
                Label("Create", systemImage: "plus.circle.fill")
            }
        } content: {
            content
        }
        .task { await model.load() }
        .onChange(of: app.refreshTick) { Task { await model.load() } }
        .onChange(of: app.pendingIntent, initial: true) { _, intent in
            switch intent {
            case .createNetwork:
                showCreate = true
            case .inspectNetwork(let name):
                model.selectedID = name
            default:
                return
            }
            app.clearIntent()
        }
        .inspector(isPresented: inspectorPresented) {
            inspector.inspectorColumnWidth(min: 300, ideal: 360, max: 500)
        }
        .sheet(isPresented: $showCreate) {
            CreateNetworkView(service: model.service) { await model.load() }
        }
        .confirmationDialog(
            "Prune unused networks?",
            isPresented: $showPruneConfirm
        ) {
            Button("Prune", role: .destructive) {
                Task { await model.prune() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes networks not referenced by any container.")
        }
        .confirmationDialog(
            "Delete “\(deleteTarget?.name ?? "")”?",
            isPresented: deleteDialogPresented,
            presenting: deleteTarget
        ) { network in
            Button("Delete", role: .destructive) {
                Task { await model.delete(network) }
            }
            .disabled(network.isBuiltin)
            Button("Cancel", role: .cancel) {}
        } message: { network in
            Text(network.isBuiltin
                ? "The built-in “default” network can’t be deleted."
                : "This removes the network. Networks used by a container can’t be deleted.")
        }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading {
            LoadingView(label: "Loading networks…")
        } else if model.isDaemonDown {
            EmptyStateView(
                systemImage: "bolt.slash",
                title: "The container service isn’t running",
                message: "Start it to manage networks.",
                actionTitle: "Open System",
                actionIcon: "gearshape.2.fill",
                action: { app.select(.system) }
            )
        } else if let message = model.errorMessage, model.networks.isEmpty {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Couldn’t load networks",
                message: message,
                actionTitle: "Retry",
                actionIcon: "arrow.clockwise",
                action: { Task { await model.load() } }
            )
        } else if model.filtered.isEmpty {
            EmptyStateView(
                systemImage: "point.3.filled.connected.trianglepath.dotted",
                title: model.searchText.isEmpty ? "No networks yet" : "No matches",
                message: model.searchText.isEmpty ? "Create a network to connect containers together." : nil,
                actionTitle: model.searchText.isEmpty ? "Create" : nil,
                actionIcon: "plus.circle.fill",
                action: { showCreate = true }
            )
        } else {
            list
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            if let message = model.errorMessage, !model.networks.isEmpty {
                InlineBanner(kind: .error, title: "Action failed", message: message)
                    .padding([.horizontal, .top], 16)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.filtered) { network in
                        NetworkRow(
                            network: network,
                            isSelected: model.selectedID == network.id,
                            isBusy: model.busyIDs.contains(network.id),
                            onSelect: {
                                withAnimation(Theme.Motion.snappy) {
                                    model.selectedID = (model.selectedID == network.id) ? nil : network.id
                                }
                            },
                            onDelete: { deleteTarget = network }
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder private var inspector: some View {
        if let network = model.selected {
            NetworkDetailView(network: network)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Select a network").font(Theme.Typography.body).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var inspectorPresented: Binding<Bool> {
        Binding(get: { model.selectedID != nil }, set: { if !$0 { model.selectedID = nil } })
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }
}
