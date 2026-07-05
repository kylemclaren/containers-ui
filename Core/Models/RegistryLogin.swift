import Foundation

/// One stored registry credential, as listed by `container registry list`.
/// JSON keys are unverified (the CLI returns `[]` when empty), so decoding is
/// tolerant of `hostname`/`host`/`server` and `username`/`user`.
struct RegistryLogin: Identifiable, Sendable, Equatable {
    var hostname: String
    var username: String?
    var created: Date?
    var modified: Date?
    var id: String { hostname }
}

extension RegistryLogin: Decodable {
    private enum CodingKeys: String, CodingKey {
        case hostname, host, server
        case username, user
        case created, modified
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let host = try c.decodeIfPresent(String.self, forKey: .hostname)
            ?? c.decodeIfPresent(String.self, forKey: .host)
            ?? c.decodeIfPresent(String.self, forKey: .server)
        guard let host, !host.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "RegistryLogin has no hostname/host/server key"))
        }
        hostname = host
        username = try c.decodeIfPresent(String.self, forKey: .username)
            ?? c.decodeIfPresent(String.self, forKey: .user)
        created = try c.decodeIfPresent(Date.self, forKey: .created)
        modified = try c.decodeIfPresent(Date.self, forKey: .modified)
    }
}

/// Canonicalizes registry hostnames so Docker Hub's aliases collapse to one key.
enum RegistryHost {
    static let canonicalDockerHub = "docker.io"
    static let dockerHubAliases: Set<String> = [
        "docker.io", "index.docker.io", "registry-1.docker.io", "registry.hub.docker.com",
    ]
    static func normalize(_ raw: String?) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return canonicalDockerHub }
        let lower = raw.trimmingCharacters(in: .whitespaces).lowercased()
        return dockerHubAliases.contains(lower) ? canonicalDockerHub : lower
    }
    static func forReference(_ reference: String) -> String {
        normalize(ImageReference.parse(reference).registry)
    }
    static func isDockerHub(_ normalizedHost: String) -> Bool { normalizedHost == canonicalDockerHub }
}
