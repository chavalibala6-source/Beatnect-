import SwiftUI

struct LyricsView: View {
    @StateObject private var lyricsService = LyricsService()
    let track: Track?
    
    var body: some View {
        ZStack {
            Color.clear
            
            if let track = track {
                if lyricsService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let error = lyricsService.error {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.5))
                        Text(error)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else if let lyrics = lyricsService.lyrics {
                    ScrollView {
                        Text(lyrics)
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .lineSpacing(10)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .padding(.bottom, 60)
                    }
                } else {
                    Text("No lyrics available")
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                Text("Play a track to see lyrics")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onChange(of: track?.id) { _ in
            fetchLyrics()
        }
        .onAppear {
            fetchLyrics()
        }
    }
    
    private func fetchLyrics() {
        guard let track = track else { return }
        lyricsService.fetchLyrics(for: track.displayArtist, title: track.displayName)
    }
}
