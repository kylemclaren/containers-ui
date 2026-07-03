import Foundation

/// A network as returned by `container network list --format json` and
/// `container network inspect` (the CLI's `NetworkResource`). The wire object
/// also carries a top-level `id` equal to `configuration.name`; we derive `id`
/// from the configuration and ignore the duplicate.
struct ContainerNetwork: Codable, Hashable, Identifiable, Sendable {
    /// The static configuration of a network.
    struct Configuration: Codable, Hashable, Sendable {
        var name: String
        /// e.g. `nat`.
        var mode: String
        var plugin: String
        /// `Date` encoded as ISO-8601 *without* fractional seconds.
        var creationDate: Date
        var labels: [String: String]
        var options: [String: String]
    }

    /// Runtime status: only present while the network is running.
    struct Status: Codable, Hashable, Sendable {
        var ipv4Gateway: String
        var ipv4Subnet: String
        /// Not guaranteed to be present even while running (e.g. IPv6 disabled).
        var ipv6Subnet: String?
    }

    var configuration: Configuration
    /// Omitted from JSON entirely when the network isn't running.
    var status: Status?

    var id: String { configuration.name }

    private enum CodingKeys: String, CodingKey {
        case configuration, status
    }
}

extension ContainerNetwork {
    var name: String { configuration.name }
    var mode: String { configuration.mode }
    var createdAt: Date { configuration.creationDate }
    var labels: [String: String] { configuration.labels }

    /// Whether this is the CLI's built-in `default` network.
    var isBuiltin: Bool {
        configuration.labels["com.apple.container.resource.role"] == "builtin"
    }

    var isRunning: Bool { status != nil }
    var ipv4Gateway: String? { status?.ipv4Gateway }
    var ipv4Subnet: String? { status?.ipv4Subnet }
    var ipv6Subnet: String? { status?.ipv6Subnet }
}
