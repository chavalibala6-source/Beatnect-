import SwiftUI

struct AlbumsGridView: View {
    let title: String
    let albums: [Album]
    @Binding var selectedAlbum: Album?
    
    @StateObject private var playerService = AudioPlayerService.shared
    @EnvironmentObject var themeManager: ThemeManager

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(albums) { album in
                        AlbumCardView(
                            album: album,
                            currentTrack: playerService.currentTrack,
                            isPlaying: playerService.isPlaying,
                            onLongPress: {
                                selectedAlbum = album
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.bottom, playerService.currentTrack != nil ? 140 : 80)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
