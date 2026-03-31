import SwiftUI
import UniformTypeIdentifiers

/// Root view — routes between Onboarding, Home, Player, Collection, and Settings.
struct ContentView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @StateObject private var libraryVM = LibraryViewModel()
    @StateObject private var library = LibraryManager.shared

    @State private var currentScreen: Screen = .home
    @State private var selectedCollection: CollectionRecord?
    @State private var showCommandPalette = false
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    enum Screen {
        case home
        case player
        case collection
        case settings
    }

    var body: some View {
        ZStack {
            mainContent

            // Command Palette overlay
            if showCommandPalette {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { showCommandPalette = false }

                CommandPalette(isPresented: $showCommandPalette) { file in
                    playerVM.openRecord(file)
                    currentScreen = .player
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    playerVM.openFile(url)
                    currentScreen = .player
                }
            }
            return true
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if currentScreen != .home {
                    Button {
                        currentScreen = .home
                    } label: {
                        Label("Home", systemImage: "house")
                    }
                }

                Button(action: openFileDialog) {
                    Label("Open File", systemImage: "folder")
                }
                .keyboardShortcut("o")

                Button {
                    showCommandPalette.toggle()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("k")

                Button {
                    currentScreen = .settings
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .keyboardShortcut(",")
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !hasCompletedOnboarding && !library.watchedFolders.isEmpty == false {
            OnboardingView(
                onFolderSelected: { path in
                    library.addFolder(path)
                    hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                },
                onSkip: {
                    hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
            )
        } else {
            switch currentScreen {
            case .home:
                HomeView(
                    libraryVM: libraryVM,
                    onSelectFile: { file in
                        playerVM.openRecord(file)
                        currentScreen = .player
                    },
                    onSelectCollection: { collection in
                        selectedCollection = collection
                        currentScreen = .collection
                    }
                )

            case .player:
                PlayerView(viewModel: playerVM)

            case .collection:
                if let collection = selectedCollection {
                    CollectionDetailView(
                        collection: collection,
                        onSelect: { file in
                            playerVM.openRecord(file)
                            currentScreen = .player
                        },
                        onBack: { currentScreen = .home }
                    )
                }

            case .settings:
                SettingsView(library: library)
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
                playerVM.openFile(url)
                currentScreen = .player
            }
        }
    }
}
