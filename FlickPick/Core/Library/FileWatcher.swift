import Foundation
import CoreServices

/// FSEvents-based file watcher for library folders.
final class FileWatcher {
    private var stream: FSEventStreamRef?
    private var watchedPaths: [String] = []
    var onChange: (([String]) -> Void)?

    func watch(paths: [String]) {
        stop()
        watchedPaths = paths
        guard !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info, let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else {
                return
            }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let changedPaths = Array(paths.prefix(numEvents))
            DispatchQueue.main.async {
                watcher.onChange?(changedPaths)
            }
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths as CFArray,
            FSEventsGetCurrentEventId(),
            0.5,  // 500ms batching latency
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    deinit {
        stop()
    }
}
