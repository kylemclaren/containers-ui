import SwiftUI
import Observation

@MainActor
@Observable
final class NetworksViewModel {
    let service: NetworkService

    var networks: [ContainerNetwork] = []
    var isLoading = false
    var errorMessage: String?
    var isDaemonDown = false

    var searchText = ""
    var selectedID: ContainerNetwork.ID?
    var busyIDs: Set<String> = []
    var isPruning = false

    init(service: NetworkService) {
        self.service = service
    }

    var filtered: [ContainerNetwork] {
        guard !searchText.isEmpty else { return networks }
        let query = searchText.lowercased()
        return networks.filter { $0.name.lowercased().contains(query) || $0.mode.lowercased().contains(query) }
    }

    var selected: ContainerNetwork? { networks.first { $0.id == selectedID } }

    var subtitle: String {
        if networks.isEmpty { return "No networks" }
        return "\(networks.count) network\(networks.count == 1 ? "" : "s")"
    }

    func load() async {
        isLoading = networks.isEmpty
        defer { isLoading = false }
        do {
            let list = try await service.list()
            withAnimation(Theme.Motion.smooth) {
                networks = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
            errorMessage = nil
            isDaemonDown = false
        } catch let error as CLIError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ network: ContainerNetwork) async {
        guard !network.isBuiltin else { return }
        await perform(network.id) { _ = try await self.service.delete(names: [network.name]) }
        if selectedID == network.id { selectedID = nil }
    }

    func prune() async {
        isPruning = true
        defer { isPruning = false }
        do {
            _ = try await service.prune()
            await load()
        } catch let error as CLIError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func perform(_ id: String, _ action: @escaping () async throws -> Void) async {
        busyIDs.insert(id)
        defer { busyIDs.remove(id) }
        do {
            try await action()
            await load()
        } catch let error as CLIError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handle(_ error: CLIError) {
        errorMessage = error.localizedDescription
        if error.isBackendUnavailable { isDaemonDown = true }
    }
}
