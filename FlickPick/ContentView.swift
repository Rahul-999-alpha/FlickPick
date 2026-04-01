import SwiftUI
import UniformTypeIdentifiers

/// Library window — routes between Onboarding, Home, Collection, and Settings.
/// Player opens in a separate window via WindowManager.
struct LibraryWindow: View {
    @ObservedObject var windowManager: WindowManager
    @StateObject private var libraryVM = LibraryViewModel()
    @ObservedObject private var library = LibraryManager.shared

    @State private var currentScreen: Screen = .home
    @State private var selectedCollection: CollectionRecord?
    @State private var showCommandPalette = false
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    enum Screen {
        case home
        case collection
        case settings
    }

    var body: some View {
        ZStack {
            mainContent

            // Command Palette overlay
            if showCommandPalette {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { showCommandPalette = false }

                CommandPalette(isPresented: $showCommandPalette) { file in
                    windowManager.openPlayer(with: file)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                guard FilenameTokenizer.isVideoFile(url.path) else { return }
                Task { @MainActor in
                    windowManager.openPlayer(with: url)
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
        if !hasCompletedOnboarding {
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
                        windowManager.openPlayer(with: file)
                    },
                    onSelectCollection: { collection in
                        selectedCollection = collection
                        currentScreen = .collection
                    }
                )

            case .collection:
                if let collection = selectedCollection {
                    CollectionDetailView(
                        collection: collection,
                        onSelect: { file in
                            windowManager.openPlayer(with: file)
                        },
                        onBack: { currentScreen = .home }
                    )
                } else {
                    Color.clear.onAppear { currentScreen = .home }
                }

            case .settings:
                SettingsView(library: library)
            }
        }
    }
}
