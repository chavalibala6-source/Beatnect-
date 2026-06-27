import SwiftUI
import Combine

// MARK: - Caches

class ImageCache {
    static let shared = NSCache<NSString, UIImage>()
}

/// URLs that have permanently failed — never retried for the lifetime of the app session.
class FailedURLCache {
    static let shared = FailedURLCache()
    private var failed = Set<String>()
    private let lock = NSLock()

    private init() {}

    func hasFailed(url: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return failed.contains(url.absoluteString)
    }

    func markFailed(url: URL) {
        lock.lock(); defer { lock.unlock() }
        failed.insert(url.absoluteString)
    }
}

// MARK: - ImageLoader

class ImageLoader: ObservableObject {
    @Published var image: UIImage? = nil
    @Published var hasFailed = false
    private var currentUrl: URL?
    private var dataTask: URLSessionDataTask?

    func load(url: URL?) {
        guard let url = url else {
            self.image = nil
            self.hasFailed = true
            return
        }

        // Already loaded or already known to fail — don't touch the network again
        if currentUrl == url { return }
        
        // Reset loader state for the new URL
        self.image = nil
        self.hasFailed = false
        
        currentUrl = url

        let key = url.absoluteString as NSString

        // 1. Memory cache hit → instant
        if let cached = ImageCache.shared.object(forKey: key) {
            self.image = cached
            self.hasFailed = false
            return
        }

        // 2. Permanently failed → show placeholder, stop
        if FailedURLCache.shared.hasFailed(url: url) {
            self.hasFailed = true
            return
        }

        self.image = nil
        self.hasFailed = false

        dataTask?.cancel()
        dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, self.currentUrl == url else { return }

            if let data = data, let loadedImage = UIImage(data: data) {
                ImageCache.shared.setObject(loadedImage, forKey: key)
                DispatchQueue.main.async {
                    if self.currentUrl == url {
                        self.image = loadedImage
                        self.hasFailed = false
                    }
                }
            } else {
                // Mark permanently failed so no future view ever retries this URL
                FailedURLCache.shared.markFailed(url: url)
                DispatchQueue.main.async {
                    if self.currentUrl == url {
                        self.hasFailed = true
                    }
                }
            }
        }
        dataTask?.resume()
    }

    deinit {
        dataTask?.cancel()
    }
}

// MARK: - CachedAsyncImage

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader = ImageLoader()

    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        // Fast path: check in-memory cache before touching the loader
        let cachedImage: UIImage? = {
            if let url = url {
                return ImageCache.shared.object(forKey: url.absoluteString as NSString)
            }
            return nil
        }()

        // Fast path: check failed cache — no network needed, skip straight to placeholder
        let alreadyFailed: Bool = {
            if let url = url { return FailedURLCache.shared.hasFailed(url: url) }
            return true  // nil URL → always show placeholder
        }()

        return Group {
            if let imageToDisplay = cachedImage ?? loader.image {
                content(Image(uiImage: imageToDisplay))
            } else {
                placeholder()
            }
        }
        .onAppear {
            if !alreadyFailed { loader.load(url: url) }
        }
        .onChange(of: url) { newUrl in
            loader.load(url: newUrl)
        }
    }
}
