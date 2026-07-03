import Foundation
import Testing

/// Verifies `VolumeService`/`NetworkService` build the exact argv the
/// `container` CLI expects, including deterministic flag ordering.
@Suite("Volume and network argument builders")
struct VolumeNetworkArgumentTests {
    @Test func volumeListAndInspect() {
        #expect(VolumeService.listArguments() == ["volume", "list", "--format", "json"])
        #expect(VolumeService.inspectArguments(names: ["data"]) == ["volume", "inspect", "data"])
        #expect(VolumeService.inspectArguments(names: ["a", "b"]) == ["volume", "inspect", "a", "b"])
        #expect(VolumeService.inspectArguments(names: []) == ["volume", "inspect"])
    }

    @Test func volumeCreate() {
        #expect(VolumeService.createArguments(name: "data") == ["volume", "create", "data"])
        #expect(VolumeService.createArguments(name: "data", size: "1G") == ["volume", "create", "-s", "1G", "data"])
        #expect(VolumeService.createArguments(name: "data", labels: ["env=prod"]) == ["volume", "create", "--label", "env=prod", "data"])
        #expect(VolumeService.createArguments(name: "data", size: "1G", labels: ["env=prod", "team=core"]) == [
            "volume", "create",
            "--label", "env=prod",
            "--label", "team=core",
            "-s", "1G",
            "data",
        ])
    }

    @Test func volumeDeleteAndPrune() {
        #expect(VolumeService.deleteArguments(names: ["data"]) == ["volume", "delete", "data"])
        #expect(VolumeService.deleteArguments(names: ["a", "b"]) == ["volume", "delete", "a", "b"])
        #expect(VolumeService.pruneArguments() == ["volume", "prune"])
    }

    @Test func networkListAndInspect() {
        #expect(NetworkService.listArguments() == ["network", "list", "--format", "json"])
        #expect(NetworkService.inspectArguments(names: ["default"]) == ["network", "inspect", "default"])
        #expect(NetworkService.inspectArguments(names: ["a", "b"]) == ["network", "inspect", "a", "b"])
        #expect(NetworkService.inspectArguments(names: []) == ["network", "inspect"])
    }

    @Test func networkCreate() {
        #expect(NetworkService.createArguments(name: "app") == ["network", "create", "app"])
        #expect(NetworkService.createArguments(name: "app", isInternal: true) == ["network", "create", "--internal", "app"])
        #expect(NetworkService.createArguments(name: "app", labels: ["env=prod"]) == ["network", "create", "--label", "env=prod", "app"])
        #expect(NetworkService.createArguments(name: "app", subnet: "192.168.1.0/24") == ["network", "create", "--subnet", "192.168.1.0/24", "app"])
        #expect(NetworkService.createArguments(name: "app", subnetV6: "fd00::/64") == ["network", "create", "--subnet-v6", "fd00::/64", "app"])
        #expect(NetworkService.createArguments(
            name: "app",
            isInternal: true,
            labels: ["env=prod", "team=core"],
            subnet: "192.168.1.0/24",
            subnetV6: "fd00::/64"
        ) == [
            "network", "create",
            "--internal",
            "--label", "env=prod",
            "--label", "team=core",
            "--subnet", "192.168.1.0/24",
            "--subnet-v6", "fd00::/64",
            "app",
        ])
    }

    @Test func networkDeleteAndPrune() {
        #expect(NetworkService.deleteArguments(names: ["app"]) == ["network", "delete", "app"])
        #expect(NetworkService.deleteArguments(names: ["a", "b"]) == ["network", "delete", "a", "b"])
        #expect(NetworkService.pruneArguments() == ["network", "prune"])
    }
}
