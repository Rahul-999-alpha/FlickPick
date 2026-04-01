import SwiftUI
import UniformTypeIdentifiers

/// First-launch view: "Where do your movies live?"
struct OnboardingView: View {
    var onFolderSelected: (String) -> Void
    var onSkip: () -> Void

    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "film.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(FP.accent)

            VStack(spacing: 8) {
                Text("Welcome to FlickPick")
                    .font(FP.titleFont)
                    .foregroundStyle(FP.textPrimary)

                Text("Where do your movies and shows live?")
                    .font(FP.subtitleFont.weight(.regular))
                    .foregroundStyle(FP.textSecondary)
            }

            // Drop zone
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isDragOver ? FP.accent : FP.border,
                            style: StrokeStyle(lineWidth: 2, dash: [8])
                        )
                        .frame(width: 400, height: 160)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isDragOver ? FP.accentGlow : Color.clear)
                        )

                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.title)
                            .foregroundStyle(FP.textSecondary)
                        Text("Drag a folder here")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FP.textPrimary)
                        Text("or click below to browse")
                            .font(FP.captionFont)
                            .foregroundStyle(FP.textSecondary)
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            Task { @MainActor in
                                onFolderSelected(url.path)
                            }
                        }
                    }
                    return true
                }

                Button("Choose Folder...") {
                    chooseFolder()
                }
                .buttonStyle(.borderedProminent)
                .tint(FP.accent)
                .controlSize(.large)
            }

            Button("Skip for now") {
                onSkip()
            }
            .buttonStyle(.plain)
            .foregroundStyle(FP.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FP.background)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder with your movies or TV shows"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    onFolderSelected(url.path)
                }
            }
        }
    }
}
