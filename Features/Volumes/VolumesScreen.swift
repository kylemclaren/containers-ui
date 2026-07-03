import SwiftUI

struct VolumesScreen: View {
    @State private var model: VolumesViewModel
    @Environment(AppModel.self) private var app

    @State private var showCreate = false
    @State private var showPruneConfirm = false
    @State private var deleteTarget: ContainerVolume?

    init(service: VolumeService) {
        _model = State(initialValue: VolumesViewModel(service: service))
    }

    var body: some View {
        @Bindable var model = model
        ScreenScaffold(title: "Volumes", subtitle: model.subtitle) {
            SearchField(text: $model.searchText, prompt: "Search volumes")
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
            case .createVolume:
                showCreate = true
            case .inspectVolume(let name):
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
            CreateVolumeView(service: model.service) { await model.load() }
        }
        .confirmationDialog(
            "Prune unused volumes?",
            isPresented: $showPruneConfirm
        ) {
            Button("Prune", role: .destructive) {
                Task { await model.prune() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes volumes not referenced by any container.")
        }
        .confirmationDialog(
            "Delete “\(deleteTarget?.name ?? "")”?",
            isPresented: deleteDialogPresented,
            presenting: deleteTarget
        ) { volume in
            Button("Delete", role: .destructive) {
                Task { await model.delete(volume) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This removes the volume. Volumes used by a container can’t be deleted.")
        }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading {
            LoadingView(label: "Loading volumes…")
        } else if model.isDaemonDown {
            EmptyStateView(
                systemImage: "bolt.slash",
                title: "The container service isn’t running",
                message: "Start it to manage volumes.",
                actionTitle: "Open System",
                actionIcon: "gearshape.2.fill",
                action: { app.select(.system) }
            )
        } else if let message = model.errorMessage, model.volumes.isEmpty {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Couldn’t load volumes",
                message: message,
                actionTitle: "Retry",
                actionIcon: "arrow.clockwise",
                action: { Task { await model.load() } }
            )
        } else if model.filtered.isEmpty {
            EmptyStateView(
                systemImage: "externaldrive",
                title: model.searchText.isEmpty ? "No volumes yet" : "No matches",
                message: model.searchText.isEmpty ? "Create a volume to persist data across containers." : nil,
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
            if let message = model.errorMessage, !model.volumes.isEmpty {
                InlineBanner(kind: .error, title: "Action failed", message: message)
                    .padding([.horizontal, .top], 16)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.filtered) { volume in
                        VolumeRow(
                            volume: volume,
                            isSelected: model.selectedID == volume.id,
                            isBusy: model.busyIDs.contains(volume.id),
                            onSelect: {
                                withAnimation(Theme.Motion.snappy) {
                                    model.selectedID = (model.selectedID == volume.id) ? nil : volume.id
                                }
                            },
                            onDelete: { deleteTarget = volume }
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder private var inspector: some View {
        if let volume = model.selected {
            VolumeDetailView(volume: volume)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Select a volume").font(Theme.Typography.body).foregroundStyle(.secondary)
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
