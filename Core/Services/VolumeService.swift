import Foundation

/// Volume management, backed by the `container volume …` CLI subcommands.
struct VolumeService: Sendable {
    let cli: ContainerCLI

    init(cli: ContainerCLI) { self.cli = cli }

    // MARK: Argument builders (pure, unit-tested)

    static func listArguments() -> [String] {
        ["volume", "list", "--format", "json"]
    }

    static func inspectArguments(names: [String]) -> [String] {
        ["volume", "inspect"] + names
    }

    static func createArguments(name: String, size: String? = nil, labels: [String] = []) -> [String] {
        var args = ["volume", "create"]
        for label in labels { args += ["--label", label] }
        if let size, !size.isEmpty { args += ["-s", size] }
        args.append(name)
        return args
    }

    static func deleteArguments(names: [String]) -> [String] {
        ["volume", "delete"] + names
    }

    static func pruneArguments() -> [String] {
        ["volume", "prune"]
    }

    // MARK: Operations

    func list() async throws -> [ContainerVolume] {
        try await cli.decode([ContainerVolume].self, from: Self.listArguments())
    }

    func inspect(names: [String]) async throws -> [ContainerVolume] {
        try await cli.decode([ContainerVolume].self, from: Self.inspectArguments(names: names))
    }

    @discardableResult
    func create(name: String, size: String? = nil, labels: [String] = []) async throws -> String {
        try await cli.text(Self.createArguments(name: name, size: size, labels: labels))
    }

    @discardableResult
    func delete(names: [String]) async throws -> String {
        try await cli.text(Self.deleteArguments(names: names))
    }

    @discardableResult
    func prune() async throws -> String {
        try await cli.text(Self.pruneArguments())
    }
}
