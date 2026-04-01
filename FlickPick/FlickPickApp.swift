import SwiftUI

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
    }
}
