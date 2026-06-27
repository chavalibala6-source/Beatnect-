import SwiftUI

struct ArtworkBackground: View {
    let artworkURL: URL?

    var body: some View {
        ZStack {
            if let url = artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            .ignoresSafeArea()
                            .blur(radius: 50)
                            .brightness(-0.3)
                    case .failure:
                        Color.black.ignoresSafeArea()
                    case .empty:
                        Color.black.ignoresSafeArea()
                    @unknown default:
                        Color.black.ignoresSafeArea()
                    }
                }
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }
}
