import SwiftUI

struct VolumeDetailView: View {
    let volume: ContainerVolume

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                configuration

                if !volume.labels.isEmpty {
                    section("Labels") {
                        ForEach(volume.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
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
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name)
                    .font(Theme.Typography.title)
                    .lineLimit(1)
                Text(volume.source)
                    .font(Theme.Typography.monoCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            CopyButton(text: volume.source)
        }
    }

    private var configuration: some View {
        section("Configuration") {
            KeyValueRow("Driver", volume.driver)
            KeyValueRow("Format", volume.format)
            KeyValueRow("Size", volume.sizeInBytes.map { Formatting.bytes($0) } ?? "—")
            KeyValueRow("Created", volume.createdAt.formatted(date: .abbreviated, time: .shortened))
            KeyValueRow("Source", volume.source, mono: true)
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
