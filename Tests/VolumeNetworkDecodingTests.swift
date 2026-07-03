import Foundation
import Testing

/// Verifies `ContainerVolume`/`ContainerNetwork` decode the exact JSON the
/// `container` CLI emits (captured live from `container` CLI 1.0.0).
@Suite("Volume and network decoding")
struct VolumeNetworkDecodingTests {
    private let decoder = ContainerCLI.decoder

    /// `container volume list --format json`.
    private static let volumeList = """
    [{"configuration":{"creationDate":"2026-07-03T12:26:21Z","driver":"local","format":"ext4","labels":{},"name":"claude-shape-probe","options":{"size":"1G"},"sizeInBytes":1073741824,"source":"/Users/kyle/Library/Application Support/com.apple.container/volumes/claude-shape-probe/volume.img"},"id":"claude-shape-probe"}]
    """

    /// `container network list --format json` — a running builtin network.
    private static let networkList = """
    [{"configuration":{"creationDate":"2026-06-24T05:49:58Z","labels":{"com.apple.container.resource.role":"builtin"},"mode":"nat","name":"default","options":{},"plugin":"container-network-vmnet"},"id":"default","status":{"ipv4Gateway":"192.168.64.1","ipv4Subnet":"192.168.64.0/24","ipv6Subnet":"fdc6:488b:575d:e436::/64"}}]
    """

    /// A network that isn't running: `status` is omitted entirely.
    private static let networkNotRunning = """
    [{"configuration":{"creationDate":"2026-06-24T05:49:58Z","labels":{},"mode":"nat","name":"idle","options":{},"plugin":"container-network-vmnet"},"id":"idle"}]
    """

    private static func data(_ string: String) -> Data { Data(string.utf8) }

    @Test("Volume list decodes, including options and sizeInBytes")
    func volumeListDecodes() throws {
        let volumes = try decoder.decode([ContainerVolume].self, from: Self.data(Self.volumeList))
        let volume = try #require(volumes.first)

        #expect(volume.id == "claude-shape-probe")
        #expect(volume.name == "claude-shape-probe")
        #expect(volume.driver == "local")
        #expect(volume.format == "ext4")
        #expect(volume.sizeInBytes == 1_073_741_824)
        #expect(volume.source == "/Users/kyle/Library/Application Support/com.apple.container/volumes/claude-shape-probe/volume.img")
        #expect(volume.labels.isEmpty)
        #expect(volume.configuration.options?["size"] == "1G")

        // ISO-8601 date without fractional seconds.
        let components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: volume.createdAt)
        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 3)
    }

    @Test("Running network decodes status, including optional ipv6Subnet")
    func networkRunningDecodes() throws {
        let networks = try decoder.decode([ContainerNetwork].self, from: Self.data(Self.networkList))
        let network = try #require(networks.first)

        #expect(network.id == "default")
        #expect(network.name == "default")
        #expect(network.mode == "nat")
        #expect(network.isRunning)
        #expect(network.isBuiltin)
        #expect(network.ipv4Gateway == "192.168.64.1")
        #expect(network.ipv4Subnet == "192.168.64.0/24")
        #expect(network.ipv6Subnet == "fdc6:488b:575d:e436::/64")
    }

    @Test("Non-running network decodes with status absent")
    func networkNotRunningDecodes() throws {
        let networks = try decoder.decode([ContainerNetwork].self, from: Self.data(Self.networkNotRunning))
        let network = try #require(networks.first)

        #expect(network.status == nil)
        #expect(!network.isRunning)
        #expect(!network.isBuiltin)
        #expect(network.ipv4Gateway == nil)
        #expect(network.ipv4Subnet == nil)
        #expect(network.ipv6Subnet == nil)
    }
}
