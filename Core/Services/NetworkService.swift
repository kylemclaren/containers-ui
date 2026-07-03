import Foundation

/// Network management, backed by the `container network …` CLI subcommands.
struct NetworkService: Sendable {
    let cli: ContainerCLI

    init(cli: ContainerCLI) { self.cli = cli }

    // MARK: Argument builders (pure, unit-tested)

    static func listArguments() -> [String] {
        ["network", "list", "--format", "json"]
    }

    static func inspectArguments(names: [String]) -> [String] {
        ["network", "inspect"] + names
    }

    static func createArguments(
        name: String,
        isInternal: Bool = false,
        labels: [String] = [],
        subnet: String? = nil,
        subnetV6: String? = nil
    ) -> [String] {
        var args = ["network", "create"]
        if isInternal { args.append("--internal") }
        for label in labels { args += ["--label", label] }
        if let subnet, !subnet.isEmpty { args += ["--subnet", subnet] }
        if let subnetV6, !subnetV6.isEmpty { args += ["--subnet-v6", subnetV6] }
        args.append(name)
        return args
    }

    static func deleteArguments(names: [String]) -> [String] {
        ["network", "delete"] + names
    }

    static func pruneArguments() -> [String] {
        ["network", "prune"]
    }

    // MARK: Operations

    func list() async throws -> [ContainerNetwork] {
        try await cli.decode([ContainerNetwork].self, from: Self.listArguments())
    }

    func inspect(names: [String]) async throws -> [ContainerNetwork] {
        try await cli.decode([ContainerNetwork].self, from: Self.inspectArguments(names: names))
    }

    @discardableResult
    func create(
        name: String,
        isInternal: Bool = false,
        labels: [String] = [],
        subnet: String? = nil,
        subnetV6: String? = nil
    ) async throws -> String {
        try await cli.text(Self.createArguments(name: name, isInternal: isInternal, labels: labels, subnet: subnet, subnetV6: subnetV6))
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
