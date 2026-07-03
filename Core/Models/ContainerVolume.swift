import Foundation

/// A named storage volume as returned by `container volume list --format json`
/// and `container volume inspect` (the CLI's `VolumeResource`). The wire object
/// also carries a top-level `id` equal to `configuration.name`; we derive `id`
/// from the configuration and ignore the duplicate.
struct ContainerVolume: Codable, Hashable, Identifiable, Sendable {
    /// The static configuration of a volume.
    struct Configuration: Codable, Hashable, Sendable {
        var name: String
        var driver: String
        var format: String
        /// `Date` encoded as ISO-8601 *without* fractional seconds.
        var creationDate: Date
        var labels: [String: String]
        /// Driver-specific options (e.g. `size` for the default `local` driver).
        /// Values may vary by driver, so keys/values are both plain strings.
        var options: [String: String]?
        /// Absent for drivers that don't report a fixed size.
        var sizeInBytes: UInt64?
        var source: String
    }

    var configuration: Configuration

    var id: String { configuration.name }

    private enum CodingKeys: String, CodingKey {
        case configuration
    }
}

extension ContainerVolume {
    var name: String { configuration.name }
    var createdAt: Date { configuration.creationDate }
    var sizeInBytes: UInt64? { configuration.sizeInBytes }
    var source: String { configuration.source }
    var labels: [String: String] { configuration.labels }
    var driver: String { configuration.driver }
    var format: String { configuration.format }
}
