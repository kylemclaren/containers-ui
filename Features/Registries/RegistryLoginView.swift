import SwiftUI

/// Sheet for `container registry login`.
struct RegistryLoginView: View {
    let service: RegistryService
    var onDone: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var server: String
    @State private var username = ""
    @State private var password = ""
    @State private var scheme: RegistryScheme = .auto
    @State private var isWorking = false
    @State private var errorMessage: String?

    init(service: RegistryService, initialServer: String = "", onDone: @escaping () async -> Void) {
        self.service = service
        self.onDone = onDone
        _server = State(initialValue: initialServer)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
                Text("Log in to registry").font(Theme.Typography.title)
                Spacer()
                CircleIconButton(systemImage: "xmark", help: "Close", size: 26) { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(title: "Server")
                    TextField("ghcr.io", text: $server)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { if canSubmit { Task { await submit() } } }
                }
                .disabled(isWorking)
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(title: "Username")
                    TextField("username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { if canSubmit { Task { await submit() } } }
                }
                .disabled(isWorking)
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(title: "Password or token")
                    SecureField("password or access token", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { if canSubmit { Task { await submit() } } }
                }
                .disabled(isWorking)
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(title: "Scheme")
                    SegmentedPill(selection: $scheme, options: [
                        (value: .auto, label: "Auto"),
                        (value: .https, label: "HTTPS"),
                        (value: .http, label: "HTTP"),
                    ])
                }
                .disabled(isWorking)
            }
            .padding(16)

            Divider()
            HStack(spacing: 10) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                Spacer()
                PillButton { dismiss() } label: { Text("Cancel") }
                PillButton(style: .accent) {
                    Task { await submit() }
                } label: {
                    if isWorking {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Log in", systemImage: "person.badge.key.fill")
                    }
                }
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 480)
    }

    private var trimmedServer: String { server.trimmingCharacters(in: .whitespaces) }
    private var trimmedUsername: String { username.trimmingCharacters(in: .whitespaces) }

    private var canSubmit: Bool {
        !trimmedServer.isEmpty && !trimmedServer.contains(" ")
            && !trimmedUsername.isEmpty && !password.isEmpty && !isWorking
    }

    private func submit() async {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await service.login(server: trimmedServer, username: trimmedUsername, password: password, scheme: scheme)
            await onDone()
            dismiss()
        } catch let error as CLIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
