import SwiftUI

/// Embeddable card listing registry logins (`container registry list`), with
/// log in / log out actions. Used on the System screen.
struct RegistriesSection: View {
    @Environment(AppModel.self) private var app

    @State private var logins: [RegistryLogin] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLogin = false
    @State private var logoutBusy: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                SectionLabel(title: "Registries")
                Spacer()
                PillButton(style: .accent) {
                    showLogin = true
                } label: {
                    Label("Log in", systemImage: "person.badge.key.fill")
                }
                .disabled(app.registryService == nil)
            }

            if isLoading {
                ProgressView().controlSize(.small)
            } else if logins.isEmpty {
                // Only assert "signed in to nothing" when the list actually
                // succeeded — an error below means we don't really know.
                if errorMessage == nil {
                    Text("Not signed in to any registries.")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(logins) { login in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(login.hostname).font(Theme.Typography.headline)
                                Text(login.username ?? "—")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            PillButton(style: .destructive) {
                                Task { await logout(login.hostname) }
                            } label: {
                                if logoutBusy.contains(login.hostname) {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            }
                        }
                        .card(padding: 14)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showLogin) {
            if let service = app.registryService {
                RegistryLoginView(service: service, initialServer: "") { await reload() }
            }
        }
        .task { await reload() }
        .onChange(of: app.refreshTick) { Task { await reload() } }
    }

    private func reload() async {
        guard let service = app.registryService else { logins = []; return }
        isLoading = logins.isEmpty
        errorMessage = nil   // a successful refresh must clear any prior error
        defer { isLoading = false }
        do { logins = try await service.list() }
        catch CLIError.decodingFailed {
            // Decode of the rich JSON failed — fall back to the verbatim hostnames
            // from `--quiet`. These must NOT be normalized: logout() sends the name
            // straight to the CLI, which stored it exactly as typed.
            let hosts = (try? await service.loggedInHostsRaw()) ?? []
            logins = hosts.sorted().map { RegistryLogin(hostname: $0, username: nil, created: nil, modified: nil) }
        }
        catch let e as CLIError { errorMessage = e.localizedDescription }
        catch { errorMessage = error.localizedDescription }
        await app.refreshRegistries()
    }

    private func logout(_ host: String) async {
        guard let service = app.registryService else { return }
        logoutBusy.insert(host)
        do {
            _ = try await service.logout(server: host)
        } catch let e as CLIError {
            errorMessage = e.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        logoutBusy.remove(host)
        await reload()
    }
}
