import Foundation
import Testing

/// Verifies registry hostname normalization and reference-derived lookups.
@Suite("Registry host")
struct RegistryHostTests {
    @Test func normalize() {
        #expect(RegistryHost.normalize("docker.io") == "docker.io")
        #expect(RegistryHost.normalize("index.docker.io") == "docker.io")
        #expect(RegistryHost.normalize("registry-1.docker.io") == "docker.io")
        #expect(RegistryHost.normalize("registry.hub.docker.com") == "docker.io")
        #expect(RegistryHost.normalize("GHCR.IO") == "ghcr.io")
        #expect(RegistryHost.normalize("localhost:5000") == "localhost:5000")
        #expect(RegistryHost.normalize(nil) == "docker.io")
        #expect(RegistryHost.normalize("") == "docker.io")
    }

    @Test func forReference() {
        #expect(RegistryHost.forReference("nginx") == "docker.io")
        #expect(RegistryHost.forReference("library/alpine") == "docker.io")
        #expect(RegistryHost.forReference("ghcr.io/owner/repo:tag") == "ghcr.io")
        #expect(RegistryHost.forReference("localhost:5000/app") == "localhost:5000")
        #expect(RegistryHost.forReference("docker.io/library/nginx:latest") == "docker.io")
    }
}
