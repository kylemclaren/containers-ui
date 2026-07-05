import Foundation

/// One stored registry credential, as listed by `container registry list`.
///
/// The shipping CLI emits `name`/`id` for the host and `creationDate`/
/// `modificationDate` for the timestamps (verified against `registry list
/// --format json`). Decoding stays tolerant of the older `hostname`/`host`/
/// `server`, `created`/`modified`, and `user` spellings so a key rename degrades
/// gracefully instead of crashing the list.
struct RegistryLogin: Identifiable, Sendable, Equatable {
    var hostname: String
    var username: String?
    var created: Date?
    var modified: Date?
    var id: String { hostname }
}

extension RegistryLogin: Decodable {
    private enum CodingKeys: String, CodingKey {
        case hostname, name, id, host, server
        case username, user
        case created, creationDate
        case modified, modificationDate
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // First key that's present wins (a long `??` chain trips the type-checker).
        func first(_ keys: CodingKeys...) throws -> String? {
            for key in keys where try c.decodeIfPresent(String.self, forKey: key) != nil {
                return try c.decodeIfPresent(String.self, forKey: key)
            }
            return nil
        }
        // Real CLI keys (`name`/`id`) first, then the older guessed spellings.
        guard let host = try first(.hostname, .name, .id, .host, .server), !host.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "RegistryLogin has no name/id/hostname key"))
        }
        hostname = host
        username = try first(.username, .user)
        created = try c.decodeIfPresent(Date.self, forKey: .creationDate)
            ?? c.decodeIfPresent(Date.self, forKey: .created)
        modified = try c.decodeIfPresent(Date.self, forKey: .modificationDate)
            ?? c.decodeIfPresent(Date.self, forKey: .modified)
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
