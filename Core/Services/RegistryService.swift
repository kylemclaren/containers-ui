import Foundation

/// TLS scheme for `registry login`. `.auto` omits the flag (CLI default).
enum RegistryScheme: String, Sendable, CaseIterable {
    case auto, https, http
    var flagValue: String? { self == .auto ? nil : rawValue }
}

/// Registry credential management (`container registry …`).
struct RegistryService: Sendable {
    let cli: ContainerCLI
    init(cli: ContainerCLI) { self.cli = cli }

    // MARK: Argument builders (pure, unit-tested)
    // NOTE: the password is NEVER an argument — it is piped via stdin.
    static func loginArguments(server: String, username: String?, scheme: RegistryScheme = .auto) -> [String] {
        var args = ["registry", "login"]
        if let s = scheme.flagValue { args += ["--scheme", s] }
        if let username, !username.isEmpty { args += ["--username", username] }
        args.append("--password-stdin")
        args.append(server)
        return args
    }
    static func logoutArguments(server: String) -> [String] { ["registry", "logout", server] }
    static func listArguments() -> [String] { ["registry", "list", "--format", "json"] }
    static func listQuietArguments() -> [String] { ["registry", "list", "--quiet"] }

    // MARK: Operations
    /// Logs in, piping the password/token to stdin (`--password-stdin`).
    /// The password is passed only as stdin `Data`, never in `arguments`.
    func login(server: String, username: String, password: String, scheme: RegistryScheme = .auto) async throws {
        let args = Self.loginArguments(server: server, username: username, scheme: scheme)
        _ = try await cli.output(args, stdin: Data(password.utf8))
    }
    @discardableResult
    func logout(server: String) async throws -> String {
        try await cli.text(Self.logoutArguments(server: server))
    }
    func list() async throws -> [RegistryLogin] {
        try await cli.decode([RegistryLogin].self, from: Self.listArguments())
    }
    func loggedInHosts() async throws -> Set<String> {
        let out = try await cli.text(Self.listQuietArguments())
        let hosts = out.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { RegistryHost.normalize($0) }
        return Set(hosts)
    }
}
