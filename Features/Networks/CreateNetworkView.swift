import SwiftUI

/// Sheet for `container network create`.
struct CreateNetworkView: View {
    let service: NetworkService
    var onDone: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isInternal = false
    @State private var subnet = ""
    @State private var subnetV6 = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
                Text("Create network").font(Theme.Typography.title)
                Spacer()
                CircleIconButton(systemImage: "xmark", help: "Close", size: 26) { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(title: "Name")
                    TextField("my-network", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { if canCreate { Task { await submit() } } }
                }
                Toggle("Host-only (internal)", isOn: $isInternal)
                    .toggleStyle(.checkbox)
                    .font(Theme.Typography.callout)
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(title: "Subnet (optional)")
                    TextField("e.g. 192.168.64.0/24", text: $subnet)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.Typography.mono)
                        .onSubmit { if canCreate { Task { await submit() } } }
                }
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(title: "IPv6 subnet (optional)")
                    TextField("e.g. fd00::/64", text: $subnetV6)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.Typography.mono)
                        .onSubmit { if canCreate { Task { await submit() } } }
                }
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
                        Label("Create", systemImage: "plus")
                    }
                }
                .disabled(!canCreate)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 480)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var canCreate: Bool {
        !trimmedName.isEmpty && !trimmedName.contains(" ") && !isWorking
    }

    private func submit() async {
        guard canCreate else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let trimmedSubnet = subnet.trimmingCharacters(in: .whitespaces)
            let trimmedSubnetV6 = subnetV6.trimmingCharacters(in: .whitespaces)
            _ = try await service.create(
                name: trimmedName,
                isInternal: isInternal,
                subnet: trimmedSubnet.isEmpty ? nil : trimmedSubnet,
                subnetV6: trimmedSubnetV6.isEmpty ? nil : trimmedSubnetV6
            )
            await onDone()
            dismiss()
        } catch let error as CLIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
