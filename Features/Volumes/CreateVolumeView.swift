import SwiftUI

/// Sheet for `container volume create`.
struct CreateVolumeView: View {
    let service: VolumeService
    var onDone: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var size = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill.badge.plus")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
                Text("Create volume").font(Theme.Typography.title)
                Spacer()
                CircleIconButton(systemImage: "xmark", help: "Close", size: 26) { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(title: "Name")
                    TextField("my-volume", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { if canCreate { Task { await submit() } } }
                }
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(title: "Size (optional)")
                    TextField("e.g. 512M, 2G — leave empty for default", text: $size)
                        .textFieldStyle(.roundedBorder)
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
            let trimmedSize = size.trimmingCharacters(in: .whitespaces)
            _ = try await service.create(name: trimmedName, size: trimmedSize.isEmpty ? nil : trimmedSize)
            await onDone()
            dismiss()
        } catch let error as CLIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
