import SwiftUI
import UniformTypeIdentifiers

@main
struct FlickPickApp: App {
    @StateObject private var playerVM = PlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(playerVM: playerVM)
                .frame(minWidth: 800, minHeight: 500)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1100, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File...") {
                    openFileDialog()
                }
                .keyboardShortcut("o")
            }
        }
    }

    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.mpeg4Movie, .movie, .quickTimeMovie, .avi]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    playerVM.openFile(url)
                }
            }
        }
    }
}
