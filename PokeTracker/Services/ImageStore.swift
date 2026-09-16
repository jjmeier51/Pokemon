import Foundation
import ImageIO
import UIKit

/// Loads card artwork. Scans are bundled with the app; if a bundled scan is low resolution
/// (or missing) the store fetches the full-size image from the network and caches it on disk.
final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()

    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let fullCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL
    private let session: URLSession
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private let lock = NSLock()

    /// Bundled scans narrower than this are considered low-res and upgraded from the network when possible.
    static let highResThreshold: CGFloat = 600

    private init() {
        thumbnailCache.countLimit = 400
        fullCache.countLimit = 24
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("CardImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpAdditionalHeaders = ["User-Agent": "PokeTracker/1.0 (iOS)"]
        session = URLSession(configuration: config)
    }

    // MARK: - Locating files

    func bundledURL(for card: Card) -> URL? {
        let bundle = Bundle.main
        for ext in ["jpg", "jpeg", "png", "webp"] {
            if let url = bundle.url(forResource: card.imageName, withExtension: ext) { return url }
            if let url = bundle.url(forResource: card.imageName, withExtension: ext, subdirectory: "CardImages") { return url }
            if let url = bundle.url(forResource: card.imageName, withExtension: ext, subdirectory: "Resources/CardImages") { return url }
        }
        return nil
    }

    private func cachedURL(for card: Card) -> URL {
        cacheDirectory.appendingPathComponent("\(card.imageName).img")
    }

    /// Whether a high-resolution version is available locally (bundled or cached).
    func hasHighResLocally(for card: Card) -> Bool {
        if FileManager.default.fileExists(atPath: cachedURL(for: card).path) { return true }
        guard let url = bundledURL(for: card) else { return false }
        return pixelWidth(of: url) >= Self.highResThreshold
    }

    private func pixelWidth(of url: URL) -> CGFloat {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? CGFloat else { return 0 }
        return width
    }

    // MARK: - Loading

    /// A downsampled image suitable for grid cells. Synchronous-friendly and cached in memory.
    func thumbnail(for card: Card, maxPixelSize: CGFloat = 480) async -> UIImage? {
        let key = "\(card.imageName)@\(Int(maxPixelSize))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        let candidate = localURL(for: card)
        let image: UIImage? = await Task.detached(priority: .userInitiated) { [candidate] in
            guard let candidate else { return nil }
            return Self.downsample(url: candidate, maxPixelSize: maxPixelSize)
        }.value
        if let image { thumbnailCache.setObject(image, forKey: key) }
        return image
    }

    /// The best full-size image: cached download → bundled scan. Upgrades low-res scans in the background.
    func fullImage(for card: Card) async -> UIImage? {
        let key = card.imageName as NSString
        if let cached = fullCache.object(forKey: key) { return cached }

        var best: UIImage?
        if let local = localURL(for: card) {
            best = await Task.detached(priority: .userInitiated) { Self.downsample(url: local, maxPixelSize: 1400) }.value
        }
        if best == nil || !hasHighResLocally(for: card) {
            if let upgraded = await downloadIfNeeded(for: card) { best = upgraded }
        }
        if let best { fullCache.setObject(best, forKey: key) }
        return best
    }

    private func localURL(for card: Card) -> URL? {
        let cached = cachedURL(for: card)
        if FileManager.default.fileExists(atPath: cached.path) { return cached }
        return bundledURL(for: card)
    }

    private func downloadIfNeeded(for card: Card) async -> UIImage? {
        guard let remote = card.remoteImageURL else { return nil }
        lock.lock()
        if let task = inflight[card.id] {
            lock.unlock()
            return await task.value
        }
        let task = Task<UIImage?, Never> { [session, cacheDirectory] in
            do {
                let (data, response) = try await session.data(from: remote)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
                guard let image = UIImage(data: data), image.size.width * image.scale >= Self.highResThreshold else { return nil }
                let target = cacheDirectory.appendingPathComponent("\(card.imageName).img")
                try? data.write(to: target, options: .atomic)
                return image
            } catch {
                return nil
            }
        }
        inflight[card.id] = task
        lock.unlock()
        let result = await task.value
        lock.lock(); inflight[card.id] = nil; lock.unlock()
        if result != nil {
            // Invalidate thumbnails so grids pick up the sharper scan next time.
            thumbnailCache.removeAllObjects()
        }
        return result
    }

    private static func downsample(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func clearDiskCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        thumbnailCache.removeAllObjects()
        fullCache.removeAllObjects()
    }
}
