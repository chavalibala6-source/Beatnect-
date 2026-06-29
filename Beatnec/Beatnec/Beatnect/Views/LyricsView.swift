import SwiftUI
import Combine

struct LyricsView: View {
    @ObservedObject private var lyricsService = LyricsService.shared
    @ObservedObject var playerService: AudioPlayerService
    
    @State private var activeLineId: UUID? = nil
    
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
                                    let isActive = (line.id == activeLineId)
                                    Text(line.text)
                                        .font(.system(size: 26, weight: .bold, design: .default))
                                        .foregroundColor(isActive ? .white : .white.opacity(0.4))
                                        .blur(radius: isActive ? 0 : 0.5)
                                        .scaleEffect(isActive ? 1.05 : 1.0, anchor: .leading)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
                                        .id(line.id)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 24)
                                }
                            }
                            .padding(.vertical, 40)
                            .padding(.bottom, 60)
                        }
                        .onReceive(playerService.$currentTime) { time in
                            updateActiveLine(time: time, proxy: proxy)
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
        activeLineId = nil
        guard let track = playerService.currentTrack else { return }
        lyricsService.fetchLyrics(for: track)
    }
    
    private func updateActiveLine(time: TimeInterval, proxy: ScrollViewProxy) {
        let lines = lyricsService.syncedLines
        guard !lines.isEmpty else { return }
        
        // Find the line that should be active right now
        var newActiveId: UUID? = nil
        for (index, line) in lines.enumerated() {
            let nextTime = index + 1 < lines.count ? lines[index + 1].time : Double.infinity
            if time >= line.time && time < nextTime {
                newActiveId = line.id
                break
            }
        }
        
        // Only update state and scroll if the active line actually changed!
        if newActiveId != activeLineId {
            activeLineId = newActiveId
            if let id = newActiveId {
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}
