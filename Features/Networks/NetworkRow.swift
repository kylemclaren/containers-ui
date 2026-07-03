import SwiftUI
import AppKit

/// A rich, hoverable card representing one network.
struct NetworkRow: View {
    let network: ContainerNetwork
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
                iconTile

                VStack(alignment: .leading, spacing: 3) {
                    Text(network.name)
                        .font(Theme.Typography.headline)
                        .lineLimit(1)
                    Text(network.configuration.plugin)
                        .font(Theme.Typography.monoCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

    private var iconTile: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color.accentColor.opacity(0.14))
            .frame(width: 36, height: 36)
            .overlay {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    if network.isRunning {
                        PulsingDot(color: .green, active: true, size: 6)
                            .offset(x: 4, y: -4)
                    }
                }
            }
    }

    @ViewBuilder private var metadata: some View {
        HStack(spacing: 6) {
            StatChip(systemImage: "point.3.connected.trianglepath.dotted", text: network.mode)
            if let subnet = network.ipv4Subnet {
                StatChip(systemImage: "network", text: subnet)
            }
            if network.isBuiltin {
                StatChip(systemImage: "lock.fill", text: "built-in")
            }
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
    /// Delete is hidden for the CLI's built-in `default` network, which it refuses
    /// to remove.
    @ViewBuilder private var menuItems: some View {
        if let subnet = network.ipv4Subnet {
            Button("Copy subnet", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(subnet, forType: .string)
            }
        }
        if let gateway = network.ipv4Gateway {
            Button("Copy gateway", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(gateway, forType: .string)
            }
        }
        if !network.isBuiltin {
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
