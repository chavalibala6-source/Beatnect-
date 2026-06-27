import SwiftUI
import Combine

class ImageCache {
    static let shared = NSCache<NSString, UIImage>()
}

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
        
        if currentUrl == url {
            return
        }
        currentUrl = url
        
        let key = url.absoluteString as NSString
        if let cached = ImageCache.shared.object(forKey: key) {
            self.image = cached
            self.hasFailed = false
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
        let cachedImage: UIImage? = {
            if let url = url {
                let key = url.absoluteString as NSString
                return ImageCache.shared.object(forKey: key)
            }
            return nil
        }()
        
        return Group {
            if let imageToDisplay = cachedImage ?? loader.image {
                content(Image(uiImage: imageToDisplay))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load(url: url)
        }
        .onChange(of: url) { newUrl in
            loader.load(url: newUrl)
        }
    }
}
