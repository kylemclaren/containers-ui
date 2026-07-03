import SwiftUI
import Observation

@MainActor
@Observable
final class VolumesViewModel {
    let service: VolumeService

    var volumes: [ContainerVolume] = []
    var isLoading = false
    var errorMessage: String?
    var isDaemonDown = false

    var searchText = ""
    var selectedID: ContainerVolume.ID?
    var busyIDs: Set<String> = []
    var isPruning = false

    init(service: VolumeService) {
        self.service = service
    }

    var filtered: [ContainerVolume] {
        guard !searchText.isEmpty else { return volumes }
        let query = searchText.lowercased()
        return volumes.filter { $0.name.lowercased().contains(query) || $0.driver.lowercased().contains(query) }
    }

    var selected: ContainerVolume? { volumes.first { $0.id == selectedID } }

    var subtitle: String {
        if volumes.isEmpty { return "No volumes" }
        let countText = "\(volumes.count) volume\(volumes.count == 1 ? "" : "s")"
        let total = volumes.compactMap(\.sizeInBytes).reduce(0, +)
        guard total > 0 else { return countText }
        return "\(countText) · \(Formatting.bytes(total)) total"
    }

    func load() async {
        isLoading = volumes.isEmpty
        defer { isLoading = false }
        do {
            let list = try await service.list()
            withAnimation(Theme.Motion.smooth) {
                volumes = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
            errorMessage = nil
            isDaemonDown = false
        } catch let error as CLIError {
            handle(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ volume: ContainerVolume) async {
        await perform(volume.id) { _ = try await self.service.delete(names: [volume.name]) }
        if selectedID == volume.id { selectedID = nil }
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
