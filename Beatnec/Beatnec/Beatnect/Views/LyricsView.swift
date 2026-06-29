import SwiftUI

struct LyricsView: View {
    @StateObject private var lyricsService = LyricsService()
    @ObservedObject var playerService: AudioPlayerService
    
    var body: some View {
        ZStack {
            Color.clear
            
            if let track = playerService.currentTrack {
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
                } else if !lyricsService.syncedLines.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(lyricsService.syncedLines) { line in
                                    let isActive = isLineActive(line)
                                    Text(line.text)
                                        .font(.system(size: 26, weight: .bold, design: .default))
                                        .foregroundColor(isActive ? .white : .white.opacity(0.4))
                                        .blur(radius: isActive ? 0 : 0.5)
                                        .scaleEffect(isActive ? 1.05 : 1.0, anchor: .leading)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
                                        .id(line.id)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 24)
                                        .onChange(of: playerService.currentTime) { _ in
                                            if isActive {
                                                withAnimation(.easeInOut(duration: 0.5)) {
                                                    proxy.scrollTo(line.id, anchor: .center)
                                                }
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 40)
                            .padding(.bottom, 60)
                        }
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
        .onChange(of: playerService.currentTrack?.id) { _ in
            fetchLyrics()
        }
        .onAppear {
            fetchLyrics()
        }
    }
    
    private func fetchLyrics() {
        guard let track = playerService.currentTrack else { return }
        lyricsService.fetchLyrics(for: track.displayArtist, title: track.displayName)
    }
    
    private func isLineActive(_ line: LyricLine) -> Bool {
        let currentTime = playerService.currentTime
        guard let index = lyricsService.syncedLines.firstIndex(of: line) else { return false }
        let nextTime = index + 1 < lyricsService.syncedLines.count ? lyricsService.syncedLines[index + 1].time : Double.infinity
        
        return currentTime >= line.time && currentTime < nextTime
    }
}
