import Foundation
import AVFoundation
import AppKit

/// Generates video thumbnails using AVFoundation (with mpv fallback for exotic formats).
actor ThumbnailGenerator {
    static let shared = ThumbnailGenerator()

    private let cacheDir: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("FlickPick/thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Generate and cache a thumbnail for a video file.
    /// Returns the path to the cached thumbnail, or nil on failure.
    func generate(for videoURL: URL) async -> String? {
        let hash = videoURL.path.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .prefix(40)
        let thumbPath = cacheDir.appendingPathComponent("\(hash).jpg")

        // Return cached if exists
        if FileManager.default.fileExists(atPath: thumbPath.path) {
            return thumbPath.path
        }

        // Generate with AVFoundation
        let asset = AVURLAsset(url: videoURL)

        do {
            let duration = try await asset.load(.duration)
            let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: 0.1) // 10% in

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 320, height: 180)

            let (image, _) = try await generator.image(at: targetTime)

            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            guard let tiffData = nsImage.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiffData),
                  let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                return nil
            }

            try jpegData.write(to: thumbPath)
            return thumbPath.path
        } catch {
            print("[FlickPick] Thumbnail failed for \(videoURL.lastPathComponent): \(error)")
            return nil
        }
    }
}
