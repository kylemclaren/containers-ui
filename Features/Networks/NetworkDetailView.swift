import SwiftUI

struct NetworkDetailView: View {
    let network: ContainerNetwork

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                configuration

                if network.isRunning {
                    section("Status") {
                        KeyValueRow("IPv4 Gateway", network.ipv4Gateway ?? "—", mono: true)
                        KeyValueRow("IPv4 Subnet", network.ipv4Subnet ?? "—", mono: true)
                        KeyValueRow("IPv6 Subnet", network.ipv6Subnet ?? "—", mono: true)
                    }
                }

                if !network.labels.isEmpty {
                    section("Labels") {
                        ForEach(network.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            KeyValueRow(key, value, mono: true)
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(network.name)
                    .font(Theme.Typography.title)
                    .lineLimit(1)
                Text(network.configuration.plugin)
                    .font(Theme.Typography.monoCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if network.isBuiltin {
                StatChip(systemImage: "lock.fill", text: "built-in")
            }
        }
    }

    private var configuration: some View {
        section("Configuration") {
            KeyValueRow("Mode", network.mode)
            KeyValueRow("Plugin", network.configuration.plugin, mono: true)
            KeyValueRow("Created", network.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(title: title)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
        }
    }
}
