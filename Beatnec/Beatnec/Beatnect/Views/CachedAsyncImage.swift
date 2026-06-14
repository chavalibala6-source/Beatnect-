import SwiftUI

class ImageCache {
    static let shared = NSCache<NSString, UIImage>()
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var uiImage: UIImage? = nil
    @State private var loadedUrl: URL? = nil
    @State private var hasFailed = false
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        
        if let url = url {
            let key = url.absoluteString as NSString
            if let cached = ImageCache.shared.object(forKey: key) {
                _uiImage = State(initialValue: cached)
                _loadedUrl = State(initialValue: url)
            }
        }
    }
    
    var body: some View {
        Group {
            if let uiImage = uiImage, loadedUrl == url {
                content(Image(uiImage: uiImage))
            } else if hasFailed {
                ZStack {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                    Image(systemName: "music.note")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            self.uiImage = nil
            self.loadedUrl = nil
            self.hasFailed = true
            return
        }
        
        let key = url.absoluteString as NSString
        if let cached = ImageCache.shared.object(forKey: key) {
            self.uiImage = cached
            self.loadedUrl = url
            self.hasFailed = false
            return
        }
        
        if loadedUrl != url {
            self.uiImage = nil
            self.loadedUrl = nil
            self.hasFailed = false
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                ImageCache.shared.setObject(image, forKey: key)
                DispatchQueue.main.async {
                    if self.url == url {
                        self.uiImage = image
                        self.loadedUrl = url
                        self.hasFailed = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    if self.url == url {
                        self.hasFailed = true
                    }
                }
            }
        }.resume()
    }
}
