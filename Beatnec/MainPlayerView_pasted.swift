
Just replace your entire MainPlayerView.swift with this file and you're done! 🎉

Mainplayerview rewritten
Code · SWIFT

import SwiftUI import MediaPlayer import Combine import UIKit import UIKit import CoreImage extension UIImage { func dominantColor() -> UIColor { guard let cgImage = self.cgImage else { return .systemBlue } let width = 40 let height = 40 le
PASTED
this is the right now I have , update with all the changes for this
11:08 PM

Complete updated MainPlayerView with all fixes - blur background, proper iPad grouping, enhanced progress slider
Complete updated MainPlayerView with all fixes - blur background, proper iPad grouping, enhanced progress slider

Complete updated MainPlayerView with all fixes - blur background, proper iPad grouping, enhanced progress slider
text
import SwiftUI
import MediaPlayer
import Combine
import UIKit

// MARK: - Artwork Background with Blur Technique

struct ArtworkBackground: View {
    let artworkURL: URL?

    var body: some View {
        ZStack {
            // Blurred artwork as background
            if let url = artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
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

            // Subtle overlay for readability
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Enhanced Progress Slider (No Thumb)

struct EnhancedProgressSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    let primaryColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let trackWidth = geometry.size.width
            let trackHeight: CGFloat = 4
            let indicatorWidth: CGFloat = 2.5
            
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.08)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: trackHeight)
                
                // Active Track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(LinearGradient(
                        colors: [primaryColor.opacity(0.8), primaryColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(0, min(trackWidth * percentage, trackWidth)), height: trackHeight)
                
                // Vertical Line Indicator (no thumb)
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: indicatorWidth / 2)
                        .fill(primaryColor)
                        .frame(width: indicatorWidth, height: 20)
                }
                .offset(x: max(0, min(trackWidth * percentage - (indicatorWidth / 2), trackWidth - indicatorWidth)))
                .animation(.spring(response: 0.15, dampingFraction: 0.7), value: percentage)
                
                // Glow effect
                Circle()
                    .fill(primaryColor.opacity(0.3))
                    .blur(radius: 8)
                    .frame(width: 14, height: 14)
                    .offset(x: max(0, min(trackWidth * percentage - 7, trackWidth - 14)))
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: percentage)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onEditingChanged(true)
                        let newPercentage = max(0, min(gesture.location.x / trackWidth, 1.0))
                        value = range.lowerBound + Double(newPercentage) * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { gesture in
                        let newPercentage = max(0, min(gesture.location.x / trackWidth, 1.0))
                        value = range.lowerBound + Double(newPercentage) * (range.upperBound - range.lowerBound)
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 20)
    }
}

// MARK: - Audio Visualizer

struct AudioBarVisualizer: View {
    let isPlaying: Bool
    @StateObject private var analyzer = SpectrumAnalyzer()

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(analyzer.magnitudes.indices, id: \.self) { i in
                let raw = CGFloat(analyzer.magnitudes[i])
                let height = isPlaying ? max(6, raw * 90) : 8
                Capsule()
                    .fill(Color.white.opacity(0.4 + Double(raw) * 0.6))
                    .frame(width: 4, height: height)
                    .animation(.spring(response: 0.12, dampingFraction: 0.65), value: height)
            }
        }
        .onAppear { analyzer.install(on: AudioPlayerService.shared.engine) }
        .onDisappear { analyzer.remove(from: AudioPlayerService.shared.engine) }
    }
}

// MARK: - Main Player View

struct MainPlayerView: View {
    @StateObject private var apiService = APIService.shared
    @StateObject private var playerService = AudioPlayerService.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var serverInput: String = ""
    @State private var documentInput: String = ""
    @State private var errorMessage: String?
    @State private var isShowingSettings = false
    @State private var isShowingPlayerDetail = false
    @State private var isLoading = false
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var selectedAlbum: Album? = nil
    @State private var scrollToTopTrigger = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationView {
                ZStack {
                    themeManager.backgroundColor
                        .opacity(0.25)
                        .ignoresSafeArea()
                    
                    NavigationLink(
                        destination: Group {
                            if let album = selectedAlbum {
                                AlbumDetailView(album: album)
                            }
                        },
                        isActive: Binding(
                            get: { selectedAlbum != nil },
                            set: { if !$0 { selectedAlbum = nil } }
                        ),
                        label: { EmptyView() }
                    )
                    .hidden()
                    
                    VStack(spacing: 0) {
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.65, green: 0.8, blue: 0.22)))
                                    .scaleEffect(1.5)
                                
                                Text("Loading library...")
                                    .font(.system(.headline))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if playerService.libraryTracks.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 64))
                                    .foregroundColor(.secondary)
                                
                                Text("Beatnect Library is Empty")
                                    .font(.headline)
                                    
                                Text("Connect to your Flask server to load tracks")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    
                                Button(action: { isShowingSettings = true }) {
                                    Text("Configure Server")
                                        .fontWeight(.bold)
                                        .padding()
                                        .frame(minWidth: 200)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                iPadLibraryView(playerService: playerService, isShowingPlayerDetail: $isShowingPlayerDetail)
                            } else if verticalSizeClass == .compact {
                                CoverFlowView(albums: albums, selectedAlbum: $selectedAlbum)
                            } else {
                                ScrollViewReader { proxy in
                                    ScrollView {
                                        Color.clear
                                            .frame(height: 1)
                                            .id("scroll_to_top_dummy")
                                        
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                                            ForEach(albums) { album in
                                                AlbumCardView(album: album,
                                                              currentTrack: playerService.currentTrack,
                                                              isPlaying: playerService.isPlaying)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .padding(.bottom, playerService.currentTrack != nil ? 90 : 16)
                                    }
                                    .onChange(of: scrollToTopTrigger) {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                            proxy.scrollTo("scroll_to_top_dummy", anchor: .top)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle(verticalSizeClass == .compact ? "" : "Beatnect")
                .navigationBarHidden(verticalSizeClass == .compact)
                .navigationBarItems(
                    leading: Group {
                        if verticalSizeClass != .compact {
                            Button(action: reloadLibrary) {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    },
                    trailing: Group {
                        if verticalSizeClass != .compact {
                            Button(action: { isShowingSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                )
            }
            
            if verticalSizeClass != .compact {
                HStack(spacing: 12) {
                    Button(action: {
                        scrollToTopTrigger.toggle()
                        reloadLibrary()
                    }) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 16)
                    
                    if let currentTrack = playerService.currentTrack {
                        MiniPlayerBar(track: currentTrack, isPlaying: playerService.isPlaying, onToggle: { playerService.togglePlayPause() }, onTap: { isShowingPlayerDetail = true })
                            .transition(.move(edge: .bottom))
                            .padding(.trailing, 16)
                    } else {
                        Spacer()
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheetView(serverInput: $serverInput, documentInput: $documentInput, isPresented: $isShowingSettings, onSave: saveServerSettings)
                .environmentObject(themeManager)
        }
        .fullScreenCover(isPresented: $isShowingPlayerDetail) {
            PlayerDetailView(playerService: playerService, isPresented: $isShowingPlayerDetail)
                .environmentObject(themeManager)
        }
        .onAppear {
            serverInput = apiService.serverAddress
            documentInput = apiService.documentName
            reloadLibrary()
        }
    }
    
    private var albums: [Album] {
        var albumDict = [String: Album]()

        for track in playerService.libraryTracks {
            // Fixed: Use album name + artist as unique key
            let albumKey = "\(track.displayAlbum)###\(track.displayArtist)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if var existingAlbum = albumDict[albumKey] {
                if !existingAlbum.tracks.contains(where: { $0.id == track.id }) {
                    existingAlbum.tracks.append(track)
                    albumDict[albumKey] = existingAlbum
                }
            } else {
                albumDict[albumKey] = Album(
                    name: track.displayAlbum,
                    artist: track.displayArtist,
                    artworkUrl: track.fullArtworkUrl,
                    tracks: [track]
                )
            }
        }

        var result = albumDict.values.map { album -> Album in
            Album(
                name: album.name,
                artist: album.artist,
                artworkUrl: album.artworkUrl,
                tracks: album.tracks.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            )
        }

        result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return result
    }
    
    private func reloadLibrary() {
        if playerService.libraryTracks.isEmpty {
            if let data = UserDefaults.standard.data(forKey: "gmp_cached_library_tracks"),
               let decoded = try? JSONDecoder().decode([Track].self, from: data) {
                playerService.libraryTracks = decoded
                if playerService.tracks.isEmpty {
                    playerService.tracks = decoded
                }
            } else {
                isLoading = true
            }
        }
        apiService.fetchTracks { result in
            isLoading = false
            switch result {
            case .success(let tracks):
                playerService.libraryTracks = tracks
                playerService.tracks = tracks
                if let data = try? JSONEncoder().encode(tracks) {
                    UserDefaults.standard.set(data, forKey: "gmp_cached_library_tracks")
                }
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func saveServerSettings() {
        apiService.serverAddress = serverInput
        apiService.documentName = documentInput
        reloadLibrary()
    }
}

// MARK: - Album Card View

struct AlbumCardView: View {
    let album: Album
    let currentTrack: Track?
    let isPlaying: Bool
    
    @State private var isHovering = false
    @StateObject private var playerService = AudioPlayerService.shared
    
    var isCurrent: Bool {
        guard let currentTrack = currentTrack else { return false }
        return album.tracks.contains { $0.id == currentTrack.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                if let url = album.artworkUrl {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.white.opacity(0.05))
                            .overlay(ProgressView())
                    }
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .overlay(Image(systemName: "music.note")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary))
                }
            }
            .frame(height: 140)
            .cornerRadius(12)
            .clipped()
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCurrent ? Color.blue.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: isCurrent ? 2 : 1))
            .shadow(color: .black.opacity(isHovering ? 0.5 : 0.25), radius: isHovering ? 16 : 8, x: 0, y: 6)
            
            Text(album.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Text(album.artist)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text("\(album.tracks.count) songs")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
            
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .onHover { isHovering = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            if let firstTrack = album.tracks.first,
               let globalIndex = playerService.libraryTracks.firstIndex(where: { $0.id == firstTrack.id }) {
                playerService.setPlaylist(tracks: playerService.libraryTracks, startAtIndex: globalIndex)
            }
        }
    }
}

// MARK: - Mini Player Bar

struct MiniPlayerBar: View {
    let track: Track
    let isPlaying: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    
    @State private var isPressed = false
    @StateObject private var playerService = AudioPlayerService.shared
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadMiniPlayer(track: track, isPlaying: isPlaying, isPressed: $isPressed, playerService: playerService, onToggle: onToggle, onTap: onTap)
        } else {
            iPhoneMiniPlayer(track: track, isPlaying: isPlaying, isPressed: $isPressed, playerService: playerService, onToggle: onToggle, onTap: onTap)
        }
    }
}

// MARK: - iPad Mini Player

private struct iPadMiniPlayer: View {
    let track: Track
    let isPlaying: Bool
    @Binding var isPressed: Bool
    @ObservedObject var playerService: AudioPlayerService
    let onToggle: () -> Void
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    var progress: Double {
        isDragging ? dragProgress : (playerService.duration > 0 ? playerService.currentTime / playerService.duration : 0)
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                artworkView
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(track.displayArtist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 220, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            Spacer()

            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.2))
                            .frame(height: 3)

                        Capsule()
                            .fill(Color.primary.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(progress), height: 3)

                        Circle()
                            .fill(Color.primary)
                            .frame(width: isDragging ? 14 : 10, height: isDragging ? 14 : 10)
                            .offset(x: geo.size.width * CGFloat(progress) - (isDragging ? 7 : 5))
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                dragProgress = max(0, min(1, value.location.x / geo.size.width))
                            }
                            .onEnded { value in
                                let p = max(0, min(1, value.location.x / geo.size.width))
                                playerService.seek(to: p * playerService.duration)
                                isDragging = false
                            }
                    )
                }
                .frame(height: 14)

                HStack {
                    Text(formatTime(playerService.currentTime))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(playerService.duration))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 320)

            Spacer()

            HStack(spacing: 20) {
                Button(action: { playerService.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onToggle) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { playerService.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            HStack(spacing: 6) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                VolumeSlider()
                    .frame(width: 100, height: 20)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 20).fill(themeManager.cardBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(themeManager.borderColor, lineWidth: 1.2))
        .shadow(color: themeManager.shadowColor, radius: 8, x: 0, y: 4)
    }

    @ViewBuilder private var artworkView: some View {
        if let url = track.fullArtworkUrl {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { ProgressView() }
            .frame(width: 48, height: 48)
            .cornerRadius(12)
            .clipped()
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
        } else {
            Image(systemName: "music.note")
                .foregroundColor(.secondary)
                .frame(width: 48, height: 48)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(12)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let m = Int(seconds) / 60; let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - iPhone Mini Player

private struct iPhoneMiniPlayer: View {
    let track: Track
    let isPlaying: Bool
    @Binding var isPressed: Bool
    @ObservedObject var playerService: AudioPlayerService
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                if let url = track.fullArtworkUrl {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                } else {
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                    
                    Text(track.displayArtist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { playerService.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.05), .black.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Player Detail View

struct PlayerDetailView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var isDraggingSlider = false
    @State private var progress: Double = 0
    
    var body: some View {
        let artworkScale = playerService.isPlaying ? 1.20 : 1.0
        let artworkShadowRadius = playerService.isPlaying ? 15.0 : 8.0
        let artworkShadowOpacity = playerService.isPlaying ? 0.45 : 0.25
        
        return GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 720
            
            ZStack {
                // ✅ BLURRED ARTWORK BACKGROUND
                ArtworkBackground(artworkURL: playerService.currentTrack?.fullArtworkUrl)
                    .ignoresSafeArea()
                
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.height > 60 {
                                    withAnimation { isPresented = false }
                                }
                            }
                    )
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    iPadPlayerDetailView(
                        playerService: playerService,
                        isPresented: $isPresented,
                        isDraggingSlider: $isDraggingSlider,
                        progress: $progress
                    )
                } else if verticalSizeClass == .compact {
                    LandscapePlayerView(playerService: playerService, isPresented: $isPresented, isDraggingSlider: $isDraggingSlider, progress: $progress, geometry: geometry, artworkScale: artworkScale, artworkShadowRadius: artworkShadowRadius, artworkShadowOpacity: artworkShadowOpacity)
                } else {
                    PortraitPlayerView(playerService: playerService, isPresented: $isPresented, isDraggingSlider: $isDraggingSlider, progress: $progress, isSmallScreen: isSmallScreen, geometry: geometry, artworkScale: artworkScale, artworkShadowRadius: artworkShadowRadius, artworkShadowOpacity: artworkShadowOpacity)
                }
            }
            .onAppear { progress = playerService.currentTime }
            .onReceive(playerService.$currentTime) { t in
                if !isDraggingSlider { progress = t }
            }
        }
    }
}

// MARK: - Portrait Player View

struct PortraitPlayerView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var isPresented: Bool
    @Binding var isDraggingSlider: Bool
    @Binding var progress: Double
    let isSmallScreen: Bool
    let geometry: GeometryProxy
    let artworkScale: CGFloat
    let artworkShadowRadius: CGFloat
    let artworkShadowOpacity: CGFloat
    
    var body: some View {
        let portraitArtworkSize = max(120.0, min(300.0, min(geometry.size.width - 64.0, geometry.size.height - 380.0)))
        
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, isSmallScreen ? 8 : 16)
            
            Spacer(minLength: isSmallScreen ? 6 : 12)
            
            if let track = playerService.currentTrack {
                if let url = track.fullArtworkUrl {
                    ZStack {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.clear
                        }
                        .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                        .scaleEffect(artworkScale)
                        .blur(radius: playerService.isPlaying ? 28 : 16)
                        .opacity(playerService.isPlaying ? 0.75 : 0.4)
                        .offset(y: playerService.isPlaying ? 16 : 8)
                        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                        
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                        .cornerRadius(20)
                        .scaleEffect(artworkScale)
                        .shadow(color: .black.opacity(artworkShadowOpacity), radius: artworkShadowRadius, x: 0, y: 5)
                        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                    }
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: portraitArtworkSize * 0.25))
                        .foregroundColor(.secondary)
                        .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                        .background(Color(.secondarySystemBackground).cornerRadius(20))
                        .shadow(radius: 8)
                }
            }
            
            Spacer(minLength: isSmallScreen ? 12 : 24)
            
            if let track = playerService.currentTrack {
                VStack(alignment: .center, spacing: 4) {
                    Text(track.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                    
                    Text(track.displayArtist)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: isSmallScreen ? 12 : 20)
            
            VStack(spacing: 6) {
                EnhancedProgressSlider(
                    value: $progress,
                    range: 0...max(playerService.duration, 1),
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing { playerService.seek(to: progress) }
                    },
                    primaryColor: .white
                )
                .padding(.horizontal, 24)
                
                HStack {
                    Text(formatTime(playerService.currentTime))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(formatTime(playerService.duration))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 24)
            }
            
            Spacer(minLength: isSmallScreen ? 12 : 20)
            
            PlayerToolbar(playerService: playerService, isSmallScreen: isSmallScreen)
            
            Spacer(minLength: isSmallScreen ? 8 : 16)
            
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                
                VolumeSlider(tintColor: .white)
                    .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, isSmallScreen ? 12 : 32)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Landscape Player View

struct LandscapePlayerView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var isPresented: Bool
    @Binding var isDraggingSlider: Bool
    @Binding var progress: Double
    let geometry: GeometryProxy
    let artworkScale: CGFloat
    let artworkShadowRadius: CGFloat
    let artworkShadowOpacity: CGFloat
    
    var body: some View {
        let landscapeArtworkSize = max(120.0, min(280.0, geometry.size.height - 64.0))
        
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            Spacer(minLength: 4)
            
            HStack(spacing: 16) {
                VStack {
                    Spacer()
                    if let track = playerService.currentTrack, let url = track.fullArtworkUrl {
                        ZStack {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(maxHeight: landscapeArtworkSize)
                            .blur(radius: playerService.isPlaying ? 24 : 16)
                            .opacity(playerService.isPlaying ? 0.75 : 0.4)
                            .offset(y: playerService.isPlaying ? 12 : 6)
                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                            
                            CachedAsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(maxHeight: landscapeArtworkSize)
                            .cornerRadius(16)
                            .scaleEffect(artworkScale)
                            .shadow(color: .black.opacity(artworkShadowOpacity), radius: artworkShadowRadius, x: 0, y: 5)
                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                        }
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                            .frame(width: 200, height: 200)
                            .background(Color(.secondarySystemBackground).cornerRadius(16))
                    }
                    Spacer()
                }
                .frame(width: geometry.size.width * 0.58)
                
                VStack(alignment: .leading, spacing: 16) {
                    if let track = playerService.currentTrack {
                        Text(track.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(track.displayArtist)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    PlayerToolbar(playerService: playerService, isSmallScreen: true)
                    Spacer()
                }
                .padding(20)
                .frame(width: geometry.size.width * 0.42)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - iPad Player Detail View

struct iPadPlayerDetailView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var isPresented: Bool
    @Binding var isDraggingSlider: Bool
    @Binding var progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 20)
                    
                    Spacer(minLength: 20)
                    
                    if let track = playerService.currentTrack, let url = track.fullArtworkUrl {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: min(geometry.size.width * 0.4, 300), height: min(geometry.size.width * 0.4, 300))
                        .cornerRadius(22)
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 10)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                            .frame(width: 300, height: 300)
                            .background(Color(.secondarySystemBackground).cornerRadius(22))
                    }
                    
                    Spacer(minLength: 16)
                    
                    if let track = playerService.currentTrack {
                        VStack(spacing: 6) {
                            Text(track.displayName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 32)
                            
                            Text(track.displayArtist)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer(minLength: 16)
                    
                    VStack(spacing: 6) {
                        EnhancedProgressSlider(
                            value: $progress,
                            range: 0...max(playerService.duration, 1),
                            onEditingChanged: { editing in
                                isDraggingSlider = editing
                                if !editing { playerService.seek(to: progress) }
                            },
                            primaryColor: .white
                        )
                        .padding(.horizontal, 36)
                        
                        HStack {
                            Text(formatTime(playerService.currentTime))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(formatTime(playerService.duration))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 36)
                    }
                    
                    Spacer(minLength: 16)
                    
                    PlayerToolbar(playerService: playerService, isSmallScreen: false)
                    Spacer(minLength: 12)
                    
                    HStack(spacing: 20) {
                        Button(action: { playerService.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(playerService.isShuffleEnabled ? .teal : Color.primary.opacity(0.3))
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                            VolumeSlider(tintColor: .white)
                                .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22)
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Button(action: { playerService.toggleRepeat() }) {
                            Image(systemName: playerService.isRepeatEnabled ? "repeat.1" : "repeat")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(playerService.isRepeatEnabled ? .purple : Color.primary.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 32)
                }
                .frame(width: geometry.size.width * 0.55, height: geometry.size.height)
                
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Up Next").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                        Spacer()
                        Text("\(playerService.tracks.count > (playerService.currentTrackIndex ?? 0) + 1 ? playerService.tracks.count - (playerService.currentTrackIndex ?? 0) - 1 : 0) songs")
                            .font(.subheadline).foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 16)
                    
                    Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array((((playerService.currentTrackIndex ?? 0) + 1)..<playerService.tracks.count).enumerated()), id: \.element) { offset, idx in
                                let track = playerService.tracks[idx]
                                HStack(spacing: 12) {
                                    Text("\(offset + 1)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(width: 22, alignment: .trailing)
                                    
                                    if let url = track.fullArtworkUrl {
                                        CachedAsyncImage(url: url) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                        }
                                        .frame(width: 48, height: 48)
                                        .cornerRadius(8)
                                        .clipped()
                                    } else {
                                        Image(systemName: "music.note")
                                            .foregroundColor(.white.opacity(0.6))
                                            .frame(width: 48, height: 48)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(track.displayName)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(track.displayArtist)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    playerService.playTrack(at: idx)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 32)
                    }
                }
                .frame(width: geometry.size.width * 0.45, height: geometry.size.height)
                .background(Color.black.opacity(0.2))
            }
        }
        .ignoresSafeArea()
        .onAppear { progress = playerService.currentTime }
        .onReceive(playerService.$currentTime) { t in
            if !isDraggingSlider { progress = t }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Player Toolbar

struct PlayerToolbar: View {
    @ObservedObject var playerService: AudioPlayerService
    var isSmallScreen: Bool
    
    var body: some View {
        HStack(spacing: 24) {
            Button { playerService.previousTrack() } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(GlassButtonStyle(isActive: false, size: isSmallScreen ? 40 : 48))

            Button { playerService.togglePlayPause() } label: {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(GlassButtonStyle(isActive: playerService.isPlaying, size: isSmallScreen ? 48 : 58))

            Button { playerService.nextTrack() } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(GlassButtonStyle(isActive: false, size: isSmallScreen ? 40 : 48))
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
    }
}

struct GlassButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var size: CGFloat = 44
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundColor(.primary)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .background(
                ZStack {
                    if isActive {
                        Circle().fill(Color.blue.opacity(0.25))
                    } else {
                        Circle().fill(Color.white.opacity(0.06))
                    }
                    Circle().fill(.ultraThinMaterial)
                }
            )
            .overlay(Circle().stroke(Color.white.opacity(isActive ? 0.5 : 0.15), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Volume Slider

struct VolumeSlider: UIViewRepresentable {
    var tintColor: UIColor = .label
    
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        return volumeView
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        for subview in uiView.subviews {
            if let slider = subview as? UISlider {
                slider.minimumTrackTintColor = tintColor
                slider.maximumTrackTintColor = tintColor.withAlphaComponent(0.3)
            }
        }
    }
}

// MARK: - iPad Library View

struct iPadLibraryView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var isShowingPlayerDetail: Bool
    @EnvironmentObject var themeManager: ThemeManager

    var albums: [Album] {
        var albumDict = [String: Album]()
        
        for track in playerService.libraryTracks {
            let albumKey = "\(track.displayAlbum)###\(track.displayArtist)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if var existingAlbum = albumDict[albumKey] {
                if !existingAlbum.tracks.contains(where: { $0.id == track.id }) {
                    existingAlbum.tracks.append(track)
                    albumDict[albumKey] = existingAlbum
                }
            } else {
                albumDict[albumKey] = Album(
                    name: track.displayAlbum,
                    artist: track.displayArtist,
                    artworkUrl: track.fullArtworkUrl,
                    tracks: [track]
                )
            }
        }
        
        return albumDict.values.map { album in
            Album(
                name: album.name,
                artist: album.artist,
                artworkUrl: album.artworkUrl,
                tracks: album.tracks.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Albums").font(.system(size: 22, weight: .bold)).foregroundColor(.primary)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(albums) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if let url = album.artworkUrl {
                                        CachedAsyncImage(url: url) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color.primary.opacity(0.07))
                                        }
                                    } else {
                                        Rectangle().fill(Color.primary.opacity(0.08))
                                    }
                                    Text(album.name).font(.system(size: 13, weight: .semibold))
                                    Text(album.artist).font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                .frame(height: 200)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        }
    }
}

// MARK: - Album Detail View

struct AlbumDetailView: View {
    let album: Album
    @StateObject private var playerService = AudioPlayerService.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor.ignoresSafeArea()
            
            if let url = album.artworkUrl {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .blur(radius: 60)
                .opacity(0.12)
                .ignoresSafeArea()
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        if let url = album.artworkUrl {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                                    .frame(width: 180, height: 180)
                            } placeholder: {
                                ProgressView().frame(width: 180, height: 180)
                            }
                            .frame(width: 180, height: 180)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                        }
                        
                        VStack(spacing: 4) {
                            Text(album.name)
                                .font(.system(.title2))
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            Text(album.artist)
                                .font(.system(.headline))
                                .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                            
                            Text("\(album.tracks.count) Songs")
                                .font(.system(.caption))
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            if !album.tracks.isEmpty {
                                playerService.setPlaylist(tracks: album.tracks, startAtIndex: 0)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Play Album").fontWeight(.bold)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 32)
                            .background(RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.65, green: 0.8, blue: 0.22)))
                            .foregroundColor(.black)
                            .shadow(color: Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.35), radius: 8, x: 0, y: 4)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 24)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                            let isCurrent = playerService.currentTrack?.id == track.id
                            
                            Button(action: {
                                playerService.setPlaylist(tracks: album.tracks, startAtIndex: index)
                            }) {
                                HStack(spacing: 16) {
                                    Text("\(index + 1)")
                                        .font(.system(.body))
                                        .foregroundColor(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .secondary)
                                        .frame(width: 28, alignment: .trailing)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.displayName)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .primary)
                                            .lineLimit(1)
                                        
                                        Text(track.displayArtist)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Spacer()
                                    
                                    if isCurrent {
                                        Image(systemName: playerService.isPlaying ? "waveform.and.mic" : "play.fill")
                                            .foregroundColor(Color(red: 0.65, green: 0.8, blue: 0.22))
                                            .font(.system(size: 14))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(RoundedRectangle(cornerRadius: 12).fill(isCurrent ? Color.white.opacity(0.06) : Color.clear))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.3) : Color.clear, lineWidth: 1.0))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settings Sheet

struct SettingsSheetView: View {
    @Binding var serverInput: String
    @Binding var documentInput: String
    @Binding var isPresented: Bool
    let onSave: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Display")) {
                    Toggle(isOn: $themeManager.isDarkMode) {
                        HStack {
                            Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(themeManager.isDarkMode ? .yellow : .orange)
                            Text(themeManager.isDarkMode ? "Dark Mode" : "Light Mode")
                        }
                    }
                }
                
                Section(header: Text("Flask Server Settings")) {
                    TextField("Server Address (e.g. https://noteslook.shop)", text: $serverInput)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Document Filter")) {
                    TextField("Document Name (e.g. global or file1)", text: $documentInput)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .
