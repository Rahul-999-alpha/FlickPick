import AppKit

/// CAMetalLayer subclass with workarounds for MoltenVK issues.
/// Prevents drawable size being set to 1x1 (causes flicker) and
/// ensures HDR EDR mode activation happens on the main thread.
class MetalLayer: CAMetalLayer {

    override var drawableSize: CGSize {
        get { super.drawableSize }
        set {
            // MoltenVK workaround: reject 1x1 sizes that cause flicker
            if Int(newValue.width) > 1 && Int(newValue.height) > 1 {
                super.drawableSize = newValue
            }
        }
    }

    override var wantsExtendedDynamicRangeContent: Bool {
        get { super.wantsExtendedDynamicRangeContent }
        set {
            if Thread.isMainThread {
                super.wantsExtendedDynamicRangeContent = newValue
            } else {
                // Use async to avoid deadlock if caller is blocking main
                DispatchQueue.main.async {
                    super.wantsExtendedDynamicRangeContent = newValue
                }
            }
        }
    }
}
