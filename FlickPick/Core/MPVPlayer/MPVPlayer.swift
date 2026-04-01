import Foundation
import AppKit
import Libmpv

/// Core mpv wrapper. Owns the mpv_handle, manages lifecycle,
/// commands, property access, and the event loop.
final class MPVPlayer: NSViewController {
    private(set) var mpv: OpaquePointer!
    private var metalLayer = MetalLayer()
    private lazy var eventQueue = DispatchQueue(label: "com.flickpick.mpv", qos: .userInitiated)
    private let mpvLock = NSLock()

    weak var delegate: MPVPlayerDelegate?
    var fileToLoad: URL?

    // MARK: - View lifecycle

    override func loadView() {
        let v = NSView(frame: .init(x: 0, y: 0, width: 960, height: 540))
        v.autoresizingMask = [.width, .height]
        self.view = v
        self.view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        metalLayer.frame = view.bounds
        metalLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.contentsGravity = .resizeAspect
        metalLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = NSColor.black.cgColor
        view.layer = metalLayer
        view.wantsLayer = true
        view.autoresizesSubviews = true

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

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        metalLayer.frame = CGRect(origin: .zero, size: size)
        metalLayer.drawableSize = CGSize(width: size.width * scale, height: size.height * scale)

        // Also update any sublayers mpv may have created
        view.layer?.sublayers?.forEach { sublayer in
            sublayer.frame = CGRect(origin: .zero, size: size)
            if let metal = sublayer as? CAMetalLayer {
                metal.drawableSize = CGSize(width: size.width * scale, height: size.height * scale)
            }
        }
        CATransaction.commit()
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

        // Render into our Metal layer — mpv's MoltenVK backend expects a CAMetalLayer pointer
        var wid = unsafeBitCast(metalLayer, to: Int64.self)
        check(mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &wid))
        check(mpv_set_option_string(mpv, "vo", "gpu-next"))
        check(mpv_set_option_string(mpv, "gpu-api", "vulkan"))
        check(mpv_set_option_string(mpv, "gpu-context", "moltenvk"))
        check(mpv_set_option_string(mpv, "hwdec", "videotoolbox"))

        // Playback behavior
        check(mpv_set_option_string(mpv, "keep-open", "yes"))
        check(mpv_set_option_string(mpv, "keepaspect", "yes"))
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
        mpv_observe_property(mpv, 0, "speed", MPV_FORMAT_DOUBLE)

        // Wakeup callback -> drain events on our serial queue
        // Use passUnretained — the view hierarchy owns our lifecycle
        mpv_set_wakeup_callback(mpv, { ctx in
            guard let ctx else { return }
            let player = Unmanaged<MPVPlayer>.fromOpaque(ctx).takeUnretainedValue()
            player.drainEvents()
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    // MARK: - Playback controls

    func loadFile(_ url: URL) {
        command("loadfile", args: [url.path, "replace"])
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

    // MARK: - Property access (thread-safe via lock)

    func getString(_ name: String) -> String {
        mpvLock.lock()
        defer { mpvLock.unlock() }
        guard mpv != nil else { return "" }
        guard let cstr = mpv_get_property_string(mpv, name) else { return "" }
        let result = String(cString: cstr)
        mpv_free(cstr)
        return result
    }

    func getDouble(_ name: String) -> Double {
        mpvLock.lock()
        defer { mpvLock.unlock() }
        guard mpv != nil else { return 0 }
        var data = Double()
        mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
        return data
    }

    func getFlag(_ name: String) -> Bool {
        mpvLock.lock()
        defer { mpvLock.unlock() }
        guard mpv != nil else { return false }
        var data: Int32 = 0
        mpv_get_property(mpv, name, MPV_FORMAT_FLAG, &data)
        return data != 0
    }

    func setFlag(_ name: String, _ flag: Bool) {
        mpvLock.lock()
        defer { mpvLock.unlock() }
        guard mpv != nil else { return }
        var data: Int32 = flag ? 1 : 0
        mpv_set_property(mpv, name, MPV_FORMAT_FLAG, &data)
    }

    func setDouble(_ name: String, _ value: Double) {
        mpvLock.lock()
        defer { mpvLock.unlock() }
        guard mpv != nil else { return }
        var data = value
        mpv_set_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
    }

    // MARK: - Command execution

    func command(_ command: String, args: [String] = []) {
        mpvLock.lock()
        defer { mpvLock.unlock() }
        guard mpv != nil else { return }
        let allArgs = [command] + args
        var cptrs: [UnsafeMutablePointer<CChar>?] = allArgs.map { strdup($0) }
        cptrs.append(nil)
        defer { cptrs.forEach { free($0) } }
        // mpv_command expects UnsafeMutablePointer<UnsafePointer<CChar>?>
        var constPtrs = cptrs.map { $0.map { UnsafePointer($0) } }
        let result = mpv_command(mpv, &constPtrs)
        check(result)
    }

    // MARK: - Event loop

    private func drainEvents() {
        eventQueue.async { [weak self] in
            guard let self else { return }
            self.mpvLock.lock()
            guard self.mpv != nil else { self.mpvLock.unlock(); return }
            self.mpvLock.unlock()

            while true {
                self.mpvLock.lock()
                guard self.mpv != nil else { self.mpvLock.unlock(); return }
                let event = mpv_wait_event(self.mpv, 0)
                self.mpvLock.unlock()

                guard let event, event.pointee.event_id != MPV_EVENT_NONE else { break }

                switch event.pointee.event_id {
                case MPV_EVENT_PROPERTY_CHANGE:
                    self.handlePropertyChange(event.pointee)

                case MPV_EVENT_END_FILE:
                    // Check the reason — only report natural EOF
                    var reason: Int32 = -1
                    if let data = event.pointee.data {
                        let endFile = UnsafePointer<mpv_event_end_file>(OpaquePointer(data)).pointee
                        reason = Int32(endFile.reason.rawValue)
                    }
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.mpvEndFile(reason: reason)
                    }

                case MPV_EVENT_FILE_LOADED:
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.mpvFileLoaded()
                    }

                case MPV_EVENT_SHUTDOWN:
                    print("[FlickPick] mpv shutdown")
                    self.mpvLock.lock()
                    let handle = self.mpv
                    self.mpv = nil
                    self.mpvLock.unlock()
                    if let handle {
                        mpv_terminate_destroy(handle)
                    }
                    return

                case MPV_EVENT_LOG_MESSAGE:
                    if let msg = UnsafeMutablePointer<mpv_event_log_message>(OpaquePointer(event.pointee.data)) {
                        if let prefix = msg.pointee.prefix, let text = msg.pointee.text {
                            let prefixStr = String(cString: prefix)
                            let textStr = String(cString: text)
                            print("[mpv/\(prefixStr)] \(textStr)", terminator: "")
                        }
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
                DispatchQueue.main.async { [weak self] in self?.delegate?.mpvPropertyChanged(name, value: value) }
            }
        case "duration":
            if let value = UnsafePointer<Double>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { [weak self] in self?.delegate?.mpvPropertyChanged(name, value: value) }
            }
        case "pause":
            if let value = UnsafePointer<Int32>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { [weak self] in self?.delegate?.mpvPropertyChanged(name, value: value != 0) }
            }
        case "eof-reached":
            if let value = UnsafePointer<Int32>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { [weak self] in self?.delegate?.mpvPropertyChanged(name, value: value != 0) }
            }
        case "volume":
            if let value = UnsafePointer<Double>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { [weak self] in self?.delegate?.mpvPropertyChanged(name, value: value) }
            }
        case "paused-for-cache":
            if let value = UnsafePointer<Int32>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { [weak self] in self?.delegate?.mpvPropertyChanged(name, value: value != 0) }
            }
        case "speed":
            if let value = UnsafePointer<Double>(OpaquePointer(property.data))?.pointee {
                DispatchQueue.main.async { [weak self] in self?.delegate?.mpvPropertyChanged(name, value: value) }
            }
        default:
            break
        }
    }

    // MARK: - Cleanup

    deinit {
        mpvLock.lock()
        let handle = mpv
        mpv = nil
        mpvLock.unlock()

        if let handle {
            mpv_set_wakeup_callback(handle, nil, nil)
            eventQueue.async {
                mpv_terminate_destroy(handle)
            }
        }
    }

    private func check(_ status: CInt) {
        if status < 0 {
            print("[FlickPick] mpv error: \(String(cString: mpv_error_string(status)))")
        }
    }
}
