import Foundation

/// Protocol for receiving mpv events in the ViewModel layer.
@MainActor
protocol MPVPlayerDelegate: AnyObject {
    func mpvPropertyChanged(_ name: String, value: Any)
    func mpvFileLoaded()
    func mpvEndFile(reason: Int32)
}
