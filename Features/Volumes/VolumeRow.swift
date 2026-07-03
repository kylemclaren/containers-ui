import SwiftUI
import AppKit

/// A rich, hoverable card representing one volume.
struct VolumeRow: View {
    let volume: ContainerVolume
    let isSelected: Bool
    let isBusy: Bool

    var onSelect: () -> Void
    var onDelete: () -> Void

    @State private var hovering = false

    /// Actions replace the info cluster in the same trailing slot (no width
    /// animation, so chip text never reflows mid-transition).
    private var showActions: Bool { hovering || isSelected || isBusy }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(volume.name)
                        .font(Theme.Typography.headline)
                        .lineLimit(1)
                    Text(volume.source)
                        .font(Theme.Typography.monoCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: .trailing) {
                    metadata
                        .fixedSize()
                        .opacity(showActions ? 0 : 1)

                    actions
                        .opacity(showActions ? 1 : 0)
                }
                .animation(Theme.Motion.smooth, value: showActions)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { menuItems }
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.rowCorner, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Metrics.rowCorner, style: .continuous)
                        .fill(hovering ? Theme.Palette.controlBackground : Color.clear)
                }
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Metrics.rowCorner, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.7) : Theme.Palette.hairline,
                              lineWidth: isSelected ? 1.5 : 1)
        }
        .onHover { hovering in
            withAnimation(Theme.Motion.snappy) { self.hovering = hovering }
        }
        // Hug the content's natural height; never stretch to fill the list.
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var metadata: some View {
        HStack(spacing: 6) {
            if let size = volume.sizeInBytes {
                StatChip(systemImage: "internaldrive", text: Formatting.bytes(size))
            }
            StatChip(systemImage: "cylinder.split.1x2", text: "\(volume.format) · \(volume.driver)")
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 6) {
            if isBusy {
                ProgressView().controlSize(.small).frame(width: Theme.Metrics.controlHeight)
            } else if showActions {
                Menu {
                    menuItems
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: Theme.Metrics.controlHeight, height: Theme.Metrics.controlHeight)
                        .contentShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: Theme.Metrics.controlHeight)
            }
        }
    }

    /// Shared contents for the hover ellipsis menu and the row's right-click menu.
    @ViewBuilder private var menuItems: some View {
        Button("Copy source path", systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(volume.source, forType: .string)
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
    }
}
