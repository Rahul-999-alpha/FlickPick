import Foundation
import AppKit
import Libmpv

/// Core mpv wrapper. Owns the mpv_handle, manages lifecycle,
/// commands, property access, and the event loop.
final class MPVPlayer: NSViewController {
    private(set) var mpv: OpaquePointer!
    private var metalLayer = MetalLayer()
    private lazy var eventQueue = DispatchQueue(label: "com.flickpick.mpv", qos: .userInitiated)

    weak var delegate: MPVPlayerDelegate?
    var fileToLoad: URL?

    // MARK: - View lifecycle

    override func loadView() {
        self.view = NSView(frame: .init(x: 0, y: 0, width: 960, height: 540))
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        metalLayer.frame = view.frame
        metalLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = NSColor.black.cgColor
        view.layer = metalLayer
        view.wantsLayer = true

        setupMPV()

        if let url = fileToLoad {
            loadFile(url)
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard let window = view.window else { return }
        let scale = window.screen?.backingScaleFactor ?? 2.0
        let size = view.bounds.size
        metalLayer.frame = CGRect(origin: .zero, size: size)
        metalLayer.drawableSize = CGSize(width: size.width * scale, height: size.height * scale)
    }

    // MARK: - mpv setup

    private func setupMPV() {
        mpv = mpv_create()
        guard mpv != nil else {
            print("[FlickPick] Failed to create mpv instance")
            return
        }

        #if DEBUG
        check(mpv_request_log_messages(mpv, "warn"))
        #else
        check(mpv_request_log_messages(mpv, "no"))
        #endif

        #if os(macOS)
        check(mpv_set_option_string(mpv, "input-media-keys", "yes"))
        #endif

        // Render into our Metal layer
        check(mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &metalLayer))
        check(mpv_set_option_string(mpv, "vo", "gpu-next"))
        check(mpv_set_option_string(mpv, "gpu-api", "vulkan"))
        check(mpv_set_option_string(mpv, "gpu-context", "moltenvk"))
        check(mpv_set_option_string(mpv, "hwdec", "videotoolbox"))

        // Playback behavior
        check(mpv_set_option_string(mpv, "keep-open", "yes"))
        check(mpv_set_option_string(mpv, "ytdl", "no"))

        // Subtitle defaults
        check(mpv_set_option_string(mpv, "subs-match-os-language", "yes"))
        check(mpv_set_option_string(mpv, "subs-fallback", "yes"))

        check(mpv_initialize(mpv))

        // Observe properties we care about
        mpv_observe_property(mpv, 0, "time-pos", MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, "duration", MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, "pause", MPV_FORMAT_FLAG)
        mpv_observe_property(mpv, 0, "eof-reached", MPV_FORMAT_FLAG)
        mpv_observe_property(mpv, 0, "volume", MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, "paused-for-cache", MPV_FORMAT_FLAG)

        // Wakeup callback -> drain events on our serial queue
        mpv_set_wakeup_callback(mpv, { ctx in
            guard let ctx else { return }
            let player = Unmanaged<MPVPlayer>.fromOpaque(ctx).takeUnretainedValue()
            player.drainEvents()
        }, Unmanaged.passRetained(self).toOpaque())
    }

    // MARK: - Playback controls

    func loadFile(_ url: URL) {
        command("loadfile", args: [url.absoluteString, "replace"])
    }

    func play() {
        setFlag("pause", false)
    }

    func pause() {
        setFlag("pause", true)
    }

    func togglePause() {
        let paused = getFlag("pause")
        setFlag("pause", !paused)
    }

    func seek(to seconds: Double) {
        command("seek", args: [String(seconds), "absolute"])
    }

    func seekRelative(_ seconds: Double) {
        command("seek", args: [String(seconds), "relative"])
    }

    func setVolume(_ volume: Double) {
        setDouble("volume", volume)
    }

    func stop() {
        command("stop")
    }

    // MARK: - Property access

    func getDouble(_ name: String) -> Double {
        guard mpv != nil else { return 0 }
        var data = Double()
        mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
        return data
    }

    func getFlag(_ name: String) -> Bool {
        guard mpv != nil else { return false }
        var data: Int32 = 0
        mpv_get_property(mpv, name, MPV_FORMAT_FLAG, &data)
        return data != 0
    }

    func setFlag(_ name: String, _ flag: Bool) {
        guard mpv != nil else { return }
        var data: Int = flag ? 1 : 0
        mpv_set_property(mpv, name, MPV_FORMAT_FLAG, &data)
    }

    func setDouble(_ name: String, _ value: Double) {
        guard mpv != nil else { return }
        var data = value
        mpv_set_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
    }

    // MARK: - Command execution

    func command(_ command: String, args: [String] = []) {
        guard mpv != nil else { return }
        var cargs: [String?] = [command] + args + [nil]
        var cptrs = cargs.map { $0.flatMap { UnsafePointer<CChar>(strdup($0)) } }
        defer { cptrs.forEach { if let p = $0 { free(UnsafeMutablePointer(mutating: p)) } } }
        let result = mpv_command(mpv, &cptrs)
        check(result)
    }

    // MARK: - Event loop

    private func drainEvents() {
        eventQueue.async { [weak self] in
            guard let self, self.mpv != nil else { return }
            while true {
                let event = mpv_wait_event(self.mpv, 0)
                guard let event, event.pointee.event_id != MPV_EVENT_NONE else { break }

                switch event.pointee.event_id {
                case MPV_EVENT_PROPERTY_CHANGE:
                    self.handlePropertyChange(event.pointee)

                case MPV_EVENT_END_FILE:
                    DispatchQueue.main.async {
                        self.delegate?.mpvEndFile()
                    }

                case MPV_EVENT_FILE_LOADED:
                    DispatchQueue.main.async {
                        self.delegate?.mpvFileLoaded()
                    }

                case MPV_EVENT_SHUTDOWN:
                    print("[FlickPick] mpv shutdown")
                    mpv_terminate_destroy(self.mpv)
                    self.mpv = nil
                    return

                case MPV_EVENT_LOG_MESSAGE:
                    if let msg = UnsafeMutablePointer<mpv_event_log_message>(OpaquePointer(event.pointee.data)) {
                        let prefix = String(cString: msg.pointee.prefix!)
                        let text = String(cString: msg.pointee.text!)
                        print("[mpv/\(prefix)] \(text)", terminator: "")
                    }

                default:
                    break
                }
            }
        }
    }

    private func handlePropertyChange(_ event: mpv_event) {
        guard let dataPtr = OpaquePointer(event.data) else { return }
        let property = UnsafePointer<mpv_event_property>(dataPtr).pointee
        let name = String(cString: property.name)

        switch name {
        case "time-pos":
            if let value = UnsafePointer<Double>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { self.delegate?.mpvPropertyChanged(name, value: value) }
            }
        case "duration":
            if let value = UnsafePointer<Double>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { self.delegate?.mpvPropertyChanged(name, value: value) }
            }
        case "pause":
            if let value = UnsafePointer<Int32>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { self.delegate?.mpvPropertyChanged(name, value: value != 0) }
            }
        case "eof-reached":
            if let value = UnsafePointer<Int32>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { self.delegate?.mpvPropertyChanged(name, value: value != 0) }
            }
        case "volume":
            if let value = UnsafePointer<Double>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { self.delegate?.mpvPropertyChanged(name, value: value) }
            }
        case "paused-for-cache":
            if let value = UnsafePointer<Int32>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { self.delegate?.mpvPropertyChanged(name, value: value != 0) }
            }
        default:
            break
        }
    }

    // MARK: - Cleanup

    deinit {
        if mpv != nil {
            mpv_set_wakeup_callback(mpv, nil, nil)
            eventQueue.sync {
                if self.mpv != nil {
                    mpv_terminate_destroy(self.mpv)
                    self.mpv = nil
                }
            }
            Unmanaged.passUnretained(self).release()
        }
    }

    private func check(_ status: CInt) {
        if status < 0 {
            print("[FlickPick] mpv error: \(String(cString: mpv_error_string(status)))")
        }
    }
}
