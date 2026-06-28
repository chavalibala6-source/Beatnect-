import SwiftUI
import AVKit
import MediaPlayer
import Combine
import UIKit

import UIKit
import CoreImage

extension UIImage {
    func dominantColor() -> UIColor {
        guard let inputImage = CIImage(image: self) else { return .systemBlue }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else { return .systemBlue }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: 1)
    }
}

struct ArtworkBackground: View {
    let color: Color

    var body: some View {
        ZStack {
            color
                .ignoresSafeArea()
            Color.black.opacity(0.18) // Subtle overlay for text readability
                .ignoresSafeArea()
        }
    }
}
struct AudioBarVisualizer: View {
    let isPlaying: Bool
    @StateObject private var analyzer = SpectrumAnalyzer()

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(analyzer.magnitudes.indices, id: \.self) { i in
                let raw    = CGFloat(analyzer.magnitudes[i])
                let height = isPlaying ? max(6, raw * 90) : 8
                Capsule()
                    .fill(Color.white.opacity(0.4 + Double(raw) * 0.6))
                    .frame(width: 4, height: height)
                    .animation(.spring(response: 0.12, dampingFraction: 0.65), value: height)
            }
        }
        .onAppear  { analyzer.install(on: AudioPlayerService.shared.engine) }
        .onDisappear { analyzer.remove(from: AudioPlayerService.shared.engine) }
    }
}

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
    enum LibraryTab: String {
        case albums, songs, playlists
    }
    
    @State private var selectedLibraryTab: LibraryTab = .albums
    @State private var scrollToTopTrigger = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationView {
                ZStack {
                    // Theme-Aware Background
                    //themeManager.backgroundColor
                     //   .ignoresSafeArea()
                        //.ignoresSafeArea()

                    themeManager.backgroundColor
                        .opacity(0.25)
                        .ignoresSafeArea()
                    
                    // Hidden NavigationLink for Cover Flow album selection
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
                        // Library Listing
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
                                // iPad: full iTunes-style sidebar + table
                                iPadLibraryView(playerService: playerService, isShowingPlayerDetail: $isShowingPlayerDetail)
                            } else if verticalSizeClass == .compact {
                                CoverFlowView(albums: albums, selectedAlbum: $selectedAlbum)
                            } else {
                                ScrollViewReader { proxy in
                                    ScrollView {
                                        Color.clear
                                            .frame(height: 1)
                                            .id("scroll_to_top_dummy")
                                        
                                        libraryContentView()
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
            // Bottom Bar with Mini Player and Icon Segmented Picker
            bottomTabBar()
            
            if isShowingPlayerDetail {
                PlayerDetailView(playerService: playerService, isPresented: $isShowingPlayerDetail)
                    .environmentObject(themeManager)
                    .preferredColorScheme(.dark)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheetView(serverInput: $serverInput, documentInput: $documentInput, isPresented: $isShowingSettings, onSave: saveServerSettings)
                .environmentObject(themeManager)
        }

        .onAppear {
            serverInput = apiService.serverAddress
            documentInput = apiService.documentName
            reloadLibrary()
        }
    }
    
    @ViewBuilder
    private func libraryContentView() -> some View {
        if selectedLibraryTab == .albums {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                ForEach(albums) { album in
                    AlbumCardView(album: album,
                                  currentTrack: playerService.currentTrack,
                                  isPlaying: playerService.isPlaying)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, playerService.currentTrack != nil ? 140 : 80)
        } else if selectedLibraryTab == .songs {
            LazyVStack(spacing: 8) {
                ForEach(Array(playerService.libraryTracks.enumerated()), id: \.offset) { index, track in
                    TrackRowView(
                        track: track,
                        isCurrent: playerService.currentTrack?.id == track.id,
                        isPlaying: playerService.isPlaying && playerService.currentTrack?.id == track.id
                    )
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        playerService.setPlaylist(tracks: playerService.libraryTracks, startAtIndex: index)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, playerService.currentTrack != nil ? 140 : 80)
        }
    }
    
    @ViewBuilder
    private func bottomTabBar() -> some View {
        if verticalSizeClass != .compact {
            VStack(spacing: 12) {
                if let currentTrack = playerService.currentTrack {
                    MiniPlayerBar(track: currentTrack,
                                  isPlaying: playerService.isPlaying,
                                  onToggle: { playerService.togglePlayPause() },
                                  onTap: { isShowingPlayerDetail = true })
                        .transition(.move(edge: .bottom))
                        .padding(.horizontal, 16)
                }
                
                Picker("", selection: $selectedLibraryTab) {
                    Image(systemName: "square.stack").tag(LibraryTab.albums)
                    Image(systemName: "music.note").tag(LibraryTab.songs)
                    Image(systemName: "music.note.list").tag(LibraryTab.playlists)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 16)
            }
            .padding(.top, 8)
            .background(
                themeManager.backgroundColor
                    .opacity(0.9)
                    .ignoresSafeArea()
            )
        }
    }
    
    private var albums: [Album] {
        var dict = [String: Album]()

        for track in playerService.libraryTracks {
            let normalizedAlbumName = track.displayAlbum
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if var existingAlbum = dict[normalizedAlbumName] {
                existingAlbum.tracks.append(track)
                dict[normalizedAlbumName] = existingAlbum
            } else {
                dict[normalizedAlbumName] = Album(
                    name: track.displayAlbum,
                    artist: track.displayArtist,
                    artworkUrl: track.fullArtworkUrl,  // may be nil; resolved below
                    tracks: [track]
                )
            }
        }

        // Update artist label for albums containing multiple artists
        var result = dict.values.map { album -> Album in
            let uniqueArtists = Set(
                album.tracks.map {
                    $0.displayArtist.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            )

            // Pick the first track that actually has an artwork URL
            let resolvedArtwork = album.artworkUrl ?? album.tracks.compactMap { $0.fullArtworkUrl }.first
            return Album(
                name: album.name,
                artist: uniqueArtists.count == 1
                    ? (uniqueArtists.first ?? "")
                    : "Various Artists",
                artworkUrl: resolvedArtwork,
                tracks: album.tracks.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            )
        }

        result.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

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
                if playerService.tracks.isEmpty {
                    playerService.tracks = tracks
                }
                if let encoded = try? JSONEncoder().encode(tracks) {
                    UserDefaults.standard.set(encoded, forKey: "gmp_cached_library_tracks")
                }
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
                print("Error fetching tracks: \(error)")
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
    @EnvironmentObject var themeManager: ThemeManager
    
    private let activeGrad = RadialGradient(
        gradient: Gradient(colors: [Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.85), Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.2)]),
        center: .center,
        startRadius: 0,
        endRadius: 20
    )
    
    private let strokeGrad = LinearGradient(
        gradient: Gradient(colors: [.white.opacity(0.8), .white.opacity(0.1), .black.opacity(0.2)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var isCurrent: Bool {
        guard let currentTrack = currentTrack else { return false }
        return album.tracks.contains { $0.id == currentTrack.id }
    }
    
    var body: some View {
        return frontView
    }
    
    
    @ViewBuilder
    private var artworkView: some View {
        if let url = album.artworkUrl {
            CachedAsyncImage(url: url) { image in
                image.resizable()
                     .aspectRatio(1.0, contentMode: .fill)
                     .frame(maxWidth: .infinity)
                     .clipped()
            } placeholder: {
                Image("music_thumb")
                     .resizable()
                     .aspectRatio(1.0, contentMode: .fill)
                     .frame(maxWidth: .infinity)
                     .clipped()
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.0, contentMode: .fit)
            .cornerRadius(12)
        } else {
            MusicPlaceholderView()
                 .frame(maxWidth: .infinity)
                 .aspectRatio(1.0, contentMode: .fit)
                 .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var hoverOverlay: some View {
        ZStack {
            Color.black.opacity(isHovering ? 0.15 : 0.0)
                .cornerRadius(12)
            
            if isHovering {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.0, contentMode: .fit)
        .cornerRadius(12)
        .clipped()
    }
    
    private var frontView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                artworkView
                hoverOverlay
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.8) : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: (isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : Color.black).opacity(isCurrent ? 0.2 : 0.1), radius: 6, x: 0, y: 3)
            
            // Text Details
            VStack(alignment: .leading, spacing: 4) {
                Text(album.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .scaleEffect(isCurrent ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrent)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
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

// MARK: - iPad Mini Player (expanded)

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

            // ── Artwork + Info (tap to open) ──────────────────────────────
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

            // ── Progress bar (centre) ─────────────────────────────────────
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.primary.opacity(0.2))
                            .frame(height: 3)

                        // Filled
                        Capsule()
                            .fill(Color.primary.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(progress), height: 3)

                        // Thumb
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

            // ── Playback controls ─────────────────────────────────────────
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

            // ── Volume ────────────────────────────────────────────────────
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            themeManager.borderColor,
                            lineWidth: 1.2
                        )
                )
        )
        .shadow(color: themeManager.shadowColor, radius: 8, x: 0, y: 4)
    }

    @ViewBuilder private var artworkView: some View {
        if let url = track.fullArtworkUrl {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image("music_thumb")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .frame(width: 48, height: 48)
            .cornerRadius(12)
            .clipped()
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
        } else {
            Image("music_thumb")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .cornerRadius(12)
                .clipped()
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let m = Int(seconds) / 60; let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - iPhone Mini Player (compact)

private struct iPhoneMiniPlayer: View {
    let track: Track
    let isPlaying: Bool
    @Binding var isPressed: Bool
    @ObservedObject var playerService: AudioPlayerService
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Main Tappable Area (Artwork + Info)
            HStack(spacing: 12) {
                // Artwork
                if let url = track.fullArtworkUrl {
                    CachedAsyncImage(url: url) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                             .frame(width: 48, height: 48)
                    } placeholder: {
                        Image("music_thumb")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
                } else {
                    Image("music_thumb")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .cornerRadius(12)
                        .clipped()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                        )
                }
                
                // Info
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            
            // Previous Button
            Button(action: { playerService.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Play/Pause Button
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Next Button
            Button(action: { playerService.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(isPlaying ? 0.5 : 0.25), .white.opacity(0.05), .black.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
        )
        .shadow(color: (isPlaying ? Color.blue : Color.black).opacity(isPlaying ? 0.35 : 0.15), radius: isPressed ? 3 : 8, x: 0, y: isPressed ? 1 : 4)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
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
                
                Section(header: Text("Connection Instructions")) {
                    Text("Enter the full URL (including port) of your Flask backend running Frame/Beatnect. Make sure both your iPhone/iPad and server are on the same Wi-Fi network.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false },
                trailing: Button("Save") {
                    onSave()
                    isPresented = false
                }
                .fontWeight(.bold)
            )
        }
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
    @State private var artworkColor: Color = Color(red: 0.08, green: 0.08, blue: 0.09)
    @State private var isShowingQueue = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingArtwork = false
    @State private var verticalDragOffset: CGFloat = 0.0
    @State private var isDraggingVertically = false
    private func updateArtworkColor() {
        guard let url = playerService.currentTrack?.fullArtworkUrl else {
            withAnimation(.easeInOut(duration: 0.5)) {
                artworkColor = Color(red: 0.08, green: 0.08, blue: 0.09)
            }
            return
        }

        let key = url.absoluteString as NSString
        if let cachedImage = ImageCache.shared.object(forKey: key) {
            let uiColor = cachedImage.dominantColor()
            withAnimation(.easeInOut(duration: 0.5)) {
                artworkColor = Color(uiColor)
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data,
                let image = UIImage(data: data)
            else { return }

            let uiColor = image.dominantColor()

            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    artworkColor = Color(uiColor)
                }
            }
        }.resume()
    }
    var body: some View {
        let artworkScale = playerService.isPlaying ? 1.20 : 1.0
        let artworkShadowRadius = playerService.isPlaying ? 15.0 : 8.0
        let artworkShadowOpacity = playerService.isPlaying ? 0.45 : 0.25
        
        return GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 720
            
            ZStack {
                // Always use Artwork background
                ArtworkBackground(color: artworkColor)
                    .ignoresSafeArea()
                

                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // iPad: full split-view layout
                    iPadPlayerDetailView(
                        playerService: playerService,
                        isPresented: $isPresented,
                        isDraggingSlider: $isDraggingSlider,
                        progress: $progress
                    )
                } else if verticalSizeClass == .compact {
                    // Landscape Layout: Image left side (60% width), controls right side (40% width)
                    let landscapeArtworkSize = max(120.0, min(280.0, geometry.size.height - (isSmallScreen ? 48.0 : 64.0)))
                    let cardHeight = geometry.size.height - (isSmallScreen ? 36.0 : 48.0)
                    
                    VStack(spacing: 0) {
                        // Top Capsule Handle for Landscape
                        Capsule()
                            .fill(Color.primary.opacity(0.4))
                            .frame(width: 40, height: 5)
                            .padding(.top, 8)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
                                        if value.translation.height > 30 {
                                            withAnimation {
                                                isPresented = false
                                            }
                                        }
                                    }
                            )
                        
                        Spacer(minLength: 4)
                        
                        HStack(spacing: 16) {
                            // Left Side: Artwork Vinyl (60% width split)
                            VStack {
                                Spacer()
                                if let track = playerService.currentTrack {
                                    ZStack {
                                        let artUrl = track.fullArtworkUrl
                                        // Glowing Artwork Drop Shadow
                                        CachedAsyncImage(url: artUrl) { image in
                                             image.resizable()
                                                  .aspectRatio(contentMode: .fill)
                                                  .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                         } placeholder: {
                                             Image("music_thumb").resizable().aspectRatio(contentMode: .fill)
                                                 .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                         }
                                        .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                        .scaleEffect(artworkScale)
                                        .blur(radius: playerService.isPlaying ? 24 : 16)
                                        .opacity(playerService.isPlaying ? 0.75 : 0.4)
                                        .offset(y: playerService.isPlaying ? 12 : 6)
                                        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                                        
                                        // Main Artwork image
                                        CachedAsyncImage(url: artUrl) { image in
                                            image.resizable()
                                                 .aspectRatio(contentMode: .fill)
                                                 .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                        } placeholder: {
                                            Image("music_thumb").resizable().aspectRatio(contentMode: .fill)
                                                .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                        }
                                        .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                        .cornerRadius(16)
                                        .clipped()
                                        .scaleEffect(artworkScale)
                                        .shadow(color: Color.black.opacity(artworkShadowOpacity), radius: artworkShadowRadius, x: 0, y: playerService.isPlaying ? 10 : 5)
                                        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                                    }
                                    .gesture(
                                        DragGesture()
                                            .onEnded { value in
                                                if value.translation.height > 50 {
                                                    withAnimation {
                                                        isPresented = false
                                                    }
                                                }
                                            }
                                    )
                                }
                                Spacer()
                            }
                            .frame(width: geometry.size.width * 0.58)
                            
                            // Right Side: Controls and Info wrapped in a liquid glass-morphic card (40% width split)
                            VStack(alignment: .leading, spacing: 0) {
                                if let track = playerService.currentTrack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ScrollingTextView(text: track.displayName, font: .title3, fontWeight: .bold, color: .white, isCentered: false)
                                        
                                        Text(track.displayArtist)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                    .padding(.top, 4)
                                }
                                
                                Spacer(minLength: 8)
                                
                                // Waveform Visualizer for Landscape
                                AudioBarVisualizer(
                                    isPlaying: playerService.isPlaying
                                )
                                .frame(height: 90)
                                .padding(.horizontal)
                                .padding(.vertical, 2)
                                
                                Spacer(minLength: 14)
                                
                                // Progress Slider
                                VStack(spacing: 4) {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            // Track background
                                            Capsule()
                                                .fill(themeManager.primaryTextColor.opacity(0.18))
                                                .frame(height: 3)
                                            
                                            // Filled track
                                            Capsule()
                                                .fill(Color(red: 0.65, green: 0.8, blue: 0.22))
                                                .frame(width: playerService.duration > 0 ? geo.size.width * CGFloat(progress / max(playerService.duration, 1)) : 0, height: 3)
                                            
                                            // Thumb dot
                                           // Circle()
                                              //  .fill(themeManager.primaryTextColor)
                                              //  .frame(width: 10, height: 10)
                                               // .offset(x: playerService.duration > 0 ? geo.size.width * CGFloat(progress / //max(playerService.duration, 1)) - 5 : -5)
                                        }
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    isDraggingSlider = true
                                                    let pct = max(0, min(1, value.location.x / geo.size.width))
                                                    progress = pct * max(playerService.duration, 1)
                                                }
                                                .onEnded { value in
                                                    let pct = max(0, min(1, value.location.x / geo.size.width))
                                                    playerService.seek(to: pct * max(playerService.duration, 1))
                                                    isDraggingSlider = false
                                                }
                                        )
                                    }
                                    .frame(height: 14)
                                    
                                    HStack {
                                        Text(formatTime(playerService.currentTime))
                                            .font(.caption2)
                                            .foregroundColor(themeManager.secondaryTextColor)
                                        Spacer()
                                        Text(formatTime(playerService.duration))
                                            .font(.caption2)
                                            .foregroundColor(themeManager.secondaryTextColor)
                                    }
                                }
                                
                                Spacer(minLength: 14)
                                
                                 // Playback Controls (Row 1)
                                 HStack {
                                     Spacer()
                                     PlayerToolbar(playerService: playerService, isSmallScreen: true)
                                     Spacer()
                                 }
                                 Spacer()
                                
                                Spacer(minLength: 12)
                                
                                // Volume Control (Row 2, replacing Shuffle & Repeat)
                                HStack(alignment: .center, spacing: 10) {
                                    Image(systemName: "speaker.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                    
                                    VolumeSlider(tintColor: themeManager.isDarkMode ? .white : .black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 22)
                                    
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                                
                                Spacer(minLength: 12)
                                
                                // Shuffle & Repeat Controls (Row 3, at the end)
                                HStack(spacing: 40) {
                                    Spacer()
                                    // Shuffle
                                    Button(action: { playerService.toggleShuffle() }) {
                                        Image(systemName: "shuffle")
                                    }
                                    .buttonStyle(LiquidGlassButtonStyle(isActive: playerService.isShuffleEnabled, activeColor: .teal, size: 32))
                                    
                                    // Repeat
                                    Button(action: { playerService.toggleRepeat() }) {
                                        Image(systemName: playerService.isRepeatEnabled ? "repeat.1" : "repeat")
                                    }
                                    .buttonStyle(LiquidGlassButtonStyle(isActive: playerService.isRepeatEnabled, activeColor: .purple, size: 32))
                                    Spacer()
                                }
                                .padding(.bottom, 4)
                            }
                            .padding(18)
                            .frame(width: geometry.size.width * 0.38, height: cardHeight)

                        }
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 4)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    // Portrait Layout
                    let portraitArtworkSize = max(120.0, min(300.0, min(geometry.size.width - 64.0, geometry.size.height - 380.0)))
                    
                    VStack(spacing: 0) {
                        // Top Pill Capsule Handle bar
                        Capsule()
                            .fill(Color.primary.opacity(0.4))
                            .frame(width: 40, height: 5)
                            .padding(.top, (isSmallScreen ? 12 : 24) + geometry.safeAreaInsets.top)
                            .padding(.bottom, 12)
                            .contentShape(Rectangle())
                        
                        Spacer() // Flexible space above artwork pushes it downwards
                        
                        if isShowingQueue {
                            QueueListView(playerService: playerService, isSmallScreen: isSmallScreen)
                                .frame(maxHeight: .infinity)
                        } else {
                            if let track = playerService.currentTrack {
                                // Static Artwork View
                                Group {
                                    if let url = track.fullArtworkUrl {
                                        CachedAsyncImage(url: url) { image in
                                            image.resizable()
                                                 .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.clear
                                        }
                                    } else {
                                        MusicPlaceholderView()
                                    }
                                }
                                .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                .cornerRadius(12)
                                .clipped()
                                .scaleEffect(artworkScale)
                                .shadow(color: Color.black.opacity(artworkShadowOpacity), radius: artworkShadowRadius, x: 0, y: playerService.isPlaying ? 12 : 6)
                                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                                
                                Spacer() // Flexible space below artwork centers it vertically
                                
                                // Track Info (directly above progress bar, no Spacer below)
                                VStack(spacing: 6) {
                                    let currentIndex = playerService.currentTrackIndex ?? 0
                                    ZStack {
                                        if isDraggingArtwork && dragOffset > 0 && currentIndex - 1 >= 0 {
                                            let prevTrack = playerService.tracks[currentIndex - 1]
                                            ScrollingTextView(text: prevTrack.displayName, font: isSmallScreen ? .title3 : .title2, fontWeight: .bold, color: .white, isCentered: true, isScrollingEnabled: false)
                                                .offset(x: dragOffset - geometry.size.width)
                                        }
                                        
                                        ScrollingTextView(text: track.displayName, font: isSmallScreen ? .title3 : .title2, fontWeight: .bold, color: .white, isCentered: true)
                                            .offset(x: dragOffset)
                                        
                                        if isDraggingArtwork && dragOffset < 0 && currentIndex + 1 < playerService.tracks.count {
                                            let nextTrack = playerService.tracks[currentIndex + 1]
                                            ScrollingTextView(text: nextTrack.displayName, font: isSmallScreen ? .title3 : .title2, fontWeight: .bold, color: .white, isCentered: true, isScrollingEnabled: false)
                                                .offset(x: dragOffset + geometry.size.width)
                                        }
                                    }
                                    .frame(height: isSmallScreen ? 30 : 40)
                                    .padding(.horizontal, 16)
                                    .clipped()
                                    
                                    Text(track.displayArtist)
                                        .font(isSmallScreen ? .subheadline : .title3)
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // Static Bottom Controls (Always visible!)
                        PortraitBottomControlsView(
                            playerService: playerService,
                            progress: $progress,
                            isDraggingSlider: $isDraggingSlider,
                            isShowingQueue: $isShowingQueue,
                            isSmallScreen: isSmallScreen
                        )
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                    }
                    }
                }
                .offset(y: verticalDragOffset)
                .scaleEffect(verticalDragOffset > 0 ? max(0.92, 1.0 - (verticalDragOffset / (geometry.size.height * 2.5))) : 1.0)
                .cornerRadius(verticalDragOffset > 0 ? min(38, verticalDragOffset / 6) : 0)
                .clipped()
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.86), value: verticalDragOffset)
                .gesture(
                    isShowingQueue ? nil :
                    DragGesture()
                        .onChanged { value in
                            if isDraggingVertically {
                                verticalDragOffset = max(0, value.translation.height)
                            } else if isDraggingArtwork {
                                dragOffset = value.translation.width
                            } else {
                                if abs(value.translation.height) > abs(value.translation.width) {
                                    isDraggingVertically = true
                                    verticalDragOffset = max(0, value.translation.height)
                                } else {
                                    isDraggingArtwork = true
                                    dragOffset = value.translation.width
                                }
                            }
                        }
                        .onEnded { value in
                            if isDraggingVertically {
                                isDraggingVertically = false
                                if verticalDragOffset > 100 {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        verticalDragOffset = geometry.size.height
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        isPresented = false
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        verticalDragOffset = 0
                                    }
                                }
                            } else if isDraggingArtwork {
                                let threshold: CGFloat = 100
                                if value.translation.width < -threshold {
                                     withAnimation(.easeOut(duration: 0.2)) {
                                         dragOffset = -geometry.size.width - 40
                                     }
                                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                         playerService.nextTrack()
                                         dragOffset = 0
                                         isDraggingArtwork = false
                                     }
                                } else if value.translation.width > threshold {
                                     withAnimation(.easeOut(duration: 0.2)) {
                                         dragOffset = geometry.size.width + 40
                                     }
                                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                         playerService.previousTrack()
                                         dragOffset = 0
                                         isDraggingArtwork = false
                                     }
                                } else {
                                     withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                         dragOffset = 0
                                         isDraggingArtwork = false
                                     }
                                }
                            }
                        }
                )

        .onAppear {
            updateArtworkColor()
        }
        
        .onChange(of: playerService.currentTrackIndex) { _ in
            updateArtworkColor()
        }
        .onReceive(playerService.$currentTime) { newTime in
            if !isDraggingSlider {
                progress = newTime
            }
        }
        .onChange(of: playerService.currentTrackIndex) { _ in
            isDraggingSlider = false
            progress = 0
        }
    }
    .ignoresSafeArea()
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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
                // ── LEFT: Player ──────────────────────────────────────────
                iPadPlayerLeftPane(
                    playerService: playerService,
                    isPresented: $isPresented,
                    isDraggingSlider: $isDraggingSlider,
                    progress: $progress,
                    width: geometry.size.width * 0.55,
                    height: geometry.size.height
                )

                // ── DIVIDER ───────────────────────────────────────────────
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)

                // ── RIGHT: Up Next ────────────────────────────────────────
                iPadUpNextPane(
                    playerService: playerService,
                    width: geometry.size.width * 0.45,
                    height: geometry.size.height
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - iPad Left Pane (Player)

struct iPadPlayerLeftPane: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var isPresented: Bool
    @Binding var isDraggingSlider: Bool
    @Binding var progress: Double
    let width: CGFloat
    let height: CGFloat

    @EnvironmentObject var themeManager: ThemeManager

    var artworkSize: CGFloat { min(width * 0.72, height * 0.44) }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.primary.opacity(0.35))
                .frame(width: 40, height: 5)
                .padding(.top, 20)

            Spacer(minLength: 20)

            // Album Artwork
            artworkView

            Spacer(minLength: 16)

            // Track info
            if let track = playerService.currentTrack {
                VStack(spacing: 6) {
                    Text(track.displayName)
                        .font(.custom("SF Pro Display", size: 24).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .padding(.horizontal, 32)

                    Text(track.displayArtist)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }

           

            // Progress
            VStack(spacing: 6) {
                PlayerProgressSlider(
                    value: $progress,
                    range: 0...max(playerService.duration, 1),
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing { playerService.seek(to: progress) }
                    }
                )
                .padding(.horizontal, 36)

                HStack {
                    Text(formatTime(playerService.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(playerService.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 36)
            }

            Spacer(minLength: 16)

            // Controls
            PlayerToolbar(playerService: playerService, isSmallScreen: false)

            Spacer(minLength: 12)

            // Volume + shuffle/repeat row
            HStack(spacing: 20) {
                Button(action: { playerService.toggleShuffle() }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(playerService.isShuffleEnabled ? .teal : Color.primary.opacity(0.3))
                }

                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.secondaryTextColor)
                    VolumeSlider(tintColor: themeManager.isDarkMode ? .white : .black)
                        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22)
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.secondaryTextColor)
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
        .frame(width: width, height: height)
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height > 50 {
                    withAnimation { isPresented = false }
                }
            }
        )
        .onAppear { progress = playerService.currentTime }
        .onReceive(playerService.$currentTime) { t in
            if !isDraggingSlider { progress = t }
        }
        .onChange(of: playerService.currentTrackIndex) { _ in
            isDraggingSlider = false
            progress = 0
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        let currentUrl = playerService.currentTrack?.fullArtworkUrl
        ZStack {
            // Background blurred glow
            CachedAsyncImage(url: currentUrl) { img in
                img.resizable().aspectRatio(contentMode: .fill)
                   .frame(width: artworkSize, height: artworkSize)
            } placeholder: {
                Image("music_thumb").resizable().aspectRatio(contentMode: .fill)
                    .frame(width: artworkSize, height: artworkSize)
            }
            .blur(radius: playerService.isPlaying ? 28 : 16)
            .opacity(playerService.isPlaying ? 0.7 : 0.35)
            .offset(y: playerService.isPlaying ? 14 : 6)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)

            // Main artwork
            CachedAsyncImage(url: currentUrl) { img in
                img.resizable().aspectRatio(contentMode: .fill)
                   .frame(width: artworkSize, height: artworkSize)
            } placeholder: {
                Image("music_thumb").resizable().aspectRatio(contentMode: .fill)
                    .frame(width: artworkSize, height: artworkSize)
            }
            .frame(width: artworkSize, height: artworkSize)
            .cornerRadius(22)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear, .black.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(playerService.isPlaying ? 0.45 : 0.25),
                    radius: playerService.isPlaying ? 16 : 8, x: 0, y: 10)
            .scaleEffect(playerService.isPlaying ? 1.04 : 1.0)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - iPad Right Pane (Up Next)

struct iPadUpNextPane: View {
    @ObservedObject var playerService: AudioPlayerService
    let width: CGFloat
    let height: CGFloat

    var upNextTracks: [Track] {
        guard let idx = playerService.currentTrackIndex,
              idx + 1 < playerService.tracks.count else { return [] }
        return Array(playerService.tracks[(idx + 1)...])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Up Next")
                    .font(.custom("SF Pro Display", size: 26).weight(.bold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(upNextTracks.count) songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            if upNextTracks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No upcoming tracks")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(upNextTracks.enumerated()), id: \.element.id) { offset, track in
                            upNextRow(track: track, index: offset + 1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(width: width, height: height)
        .background(Color.primary.opacity(0.02))
    }

    @ViewBuilder
    private func upNextRow(track: Track, index: Int) -> some View {
        HStack(spacing: 12) {
            // Index number
            Text("\(index)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 22, alignment: .trailing)

            // Artwork
            Group {
                if let url = track.fullArtworkUrl {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { Color.gray.opacity(0.3) }
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                        .frame(width: 48, height: 48)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(track.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(track.displayArtist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.clear)
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            if let idx = playerService.tracks.firstIndex(where: { $0.id == track.id }) {
                playerService.playTrack(at: idx)
            }
        }
    }
}

// MARK: - Scrolling Text View

struct ScrollingTextView: View {
    let text: String
    var font: Font = .body
    var fontWeight: Font.Weight = .bold
    var color: Color = .primary
    var isCentered: Bool = true
    var isScrollingEnabled: Bool = true
    
    @State private var position: CGFloat = 0.0
    @State private var textWidth: CGFloat = 0.0
    @State private var containerWidth: CGFloat = 0.0
    @State private var scrollTask: Task<Void, Never>? = nil
    
    var body: some View {
        GeometryReader { geometry in
            let isTooLong = textWidth > geometry.size.width
            
            HStack(spacing: 0) {
                if isCentered && !isTooLong {
                    Spacer()
                }
                
                ZStack(alignment: .leading) {
                    Text(text)
                        .font(font)
                        .fontWeight(fontWeight)
                        .foregroundColor(color)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(
                            GeometryReader { textGeometry in
                                Color.clear
                                    .onAppear {
                                        self.textWidth = textGeometry.size.width
                                        setupScrolling(containerWidth: geometry.size.width)
                                    }
                                    .onChange(of: text) { _ in
                                        self.textWidth = textGeometry.size.width
                                        self.position = 0.0
                                        setupScrolling(containerWidth: geometry.size.width)
                                    }
                            }
                        )
                        .offset(x: position)
                }
                .frame(width: isTooLong ? geometry.size.width : textWidth, alignment: .leading)
                .clipped()
                
                if isCentered && !isTooLong {
                    Spacer()
                }
            }
            .onAppear {
                self.containerWidth = geometry.size.width
            }
            .onChange(of: geometry.size.width) { newWidth in
                self.containerWidth = newWidth
                setupScrolling(containerWidth: newWidth)
            }
            .onDisappear {
                scrollTask?.cancel()
            }
            .onChange(of: isScrollingEnabled) { enabled in
                if enabled {
                    setupScrolling(containerWidth: containerWidth)
                } else {
                    scrollTask?.cancel()
                    position = 0.0
                }
            }
        }
        .frame(height: fontHeight())
    }
    
    private func fontHeight() -> CGFloat {
        if font == .title { return 36 }
        if font == .title2 { return 28 }
        if font == .title3 { return 24 }
        if font == .headline { return 22 }
        if font == .subheadline { return 20 }
        return 24
    }
    
    private func setupScrolling(containerWidth: CGFloat) {
        scrollTask?.cancel()
        guard isScrollingEnabled else {
            position = 0.0
            return
        }
        scrollTask = Task {
            await startScrollingLoop(containerWidth: containerWidth)
        }
    }
    
    private func startScrollingLoop(containerWidth: CGFloat) async {
        position = 0.0
        
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        if Task.isCancelled { return }
        
        guard textWidth > containerWidth, containerWidth > 0 else {
            return
        }
        
        let scrollSpeed: Double = 30.0 // points per second
        let distance = textWidth - containerWidth + 20.0
        let duration = Double(distance) / scrollSpeed
        
        withAnimation(.linear(duration: duration)) {
            position = -distance
        }
        
        try? await Task.sleep(nanoseconds: UInt64((duration + 1.5) * 1_000_000_000))
        if Task.isCancelled { return }
        
        withAnimation(.easeInOut(duration: 1.0)) {
            position = 0.0
        }
        
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        if Task.isCancelled { return }
        
        await startScrollingLoop(containerWidth: containerWidth)
    }
}

struct VolumeSlider: UIViewRepresentable {
    var tintColor: UIColor = .label
    
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        return volumeView
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        // Slim track, tiny thumb
        for subview in uiView.subviews {
            if let slider = subview as? UISlider {
                slider.minimumTrackTintColor = tintColor
                slider.maximumTrackTintColor = tintColor.withAlphaComponent(0.28)
                // Scale down the thumb to a small dot
                let thumbSize: CGFloat = 10
                UIGraphicsBeginImageContextWithOptions(CGSize(width: thumbSize, height: thumbSize), false, 0)
                if let ctx = UIGraphicsGetCurrentContext() {
                    ctx.setFillColor(tintColor.cgColor)
                    ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: thumbSize, height: thumbSize))
                    let thumbImage = UIGraphicsGetImageFromCurrentImageContext()
                    slider.setThumbImage(thumbImage, for: .normal)
                    slider.setThumbImage(thumbImage, for: .highlighted)
                }
                UIGraphicsEndImageContext()
            }
        }
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var activeColor: Color = .blue
    var size: CGFloat = 40
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundColor(.primary)
            .frame(width: size, height: size)
            .background(
                ZStack {
                    if isActive {
                        // Liquid glowing background
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [activeColor.opacity(0.65), activeColor.opacity(0.1)]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: size * 0.6
                                )
                            )
                            .blur(radius: 2)
                        
                        Circle()
                            .fill(activeColor.opacity(0.2))
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    }
                    
                    // Glass material
                    Circle()
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .white.opacity(isActive ? 0.7 : 0.3),
                                .white.opacity(0.05),
                                .black.opacity(0.15)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: (isActive ? activeColor : Color.black).opacity(isActive ? 0.35 : 0.15), radius: configuration.isPressed ? 3 : 8, x: 0, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}


// MARK: - 3D Cover Flow Views (iOS 6 Style)

struct CoverFlowView: View {
    let albums: [Album]
    @Binding var selectedAlbum: Album?
    
    @State private var currentIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var hasInitialized = false
    @StateObject private var playerService = AudioPlayerService.shared
    @State private var progress: Double = 0
    @State private var isDraggingProgress = false
    
    // Configurations for larger sizing
    let coverWidth: CGFloat = 260
    let coverHeight: CGFloat = 260
    let reflectionHeight: CGFloat = 100
    
    // Spacing step between cards (uniform gap)
    let step: CGFloat = 220
    
    var currentAlbum: Album? {
        albums.indices.contains(currentIndex) ? albums[currentIndex] : nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            // Drag gesture mapping to fractional indices
            let fractionalIndex = Double(currentIndex) - Double(dragOffset / step)
            
            ZStack(alignment: .center) {
                // Premium Black Background
                Color.black
                    .ignoresSafeArea()
                
                // Reflections Floor Gradient Overlay
                VStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.9)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: screenHeight * 0.55)
                }
                .ignoresSafeArea(edges: .bottom)
                
                // ── Cards area (left, pushed lower with top padding) ──
                VStack(spacing: 0) {
                    // Top breathing room so cards don't touch the status bar
                    Spacer().frame(height: 36)
                    
                    Spacer()
                    
                    // ZStack of all cards
                    ZStack {
                        let visibleRange = max(0, currentIndex - 3)...min(albums.count - 1, currentIndex + 3)
                        ForEach(Array(visibleRange), id: \.self) { index in
                            let album = albums[index]
                            CoverFlowCard(
                                album: album,
                                width: coverWidth,
                                height: coverHeight,
                                reflectionHeight: reflectionHeight,
                                index: index,
                                fractionalIndex: fractionalIndex,
                                step: step,
                                currentIndex: $currentIndex,
                                selectedAlbum: $selectedAlbum
                            )
                        }
                    }
                    .frame(width: screenWidth - 110, height: coverHeight + reflectionHeight)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 12)
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let velocity = value.predictedEndTranslation.width
                                var offsetIndex = -Int(round(value.translation.width / step))
                                if velocity < -100 { offsetIndex = max(offsetIndex, 1) }
                                else if velocity > 100 { offsetIndex = min(offsetIndex, -1) }
                                let newIndex = min(albums.count - 1, max(0, currentIndex + offsetIndex))
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                    currentIndex = newIndex
                                }
                            }
                    )
                    
                    // Album name + artist beneath cards
                    VStack(spacing: 3) {
                        Text(currentAlbum?.name ?? "")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(currentAlbum?.artist ?? "")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                            .lineLimit(1)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .padding(.horizontal, 16)
                    .animation(.easeInOut(duration: 0.22), value: currentIndex)
                }
                .frame(width: screenWidth, height: screenHeight)
                
                // ── BOTTOM BAR: progress bar + controls + volume ──
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        
                        // ── Progress Bar ──────────────────────────────────
                        VStack(spacing: 5) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Track background
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 3)
                                    
                                    // Filled track
                                    Capsule()
                                        .fill(Color(red: 0.65, green: 0.8, blue: 0.22))
                                        .frame(width: playerService.duration > 0 ? geo.size.width * CGFloat(progress / max(playerService.duration, 1)) : 0, height: 3)
                                    
                                    // Thumb dot
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: isDraggingProgress ? 14 : 10, height: isDraggingProgress ? 14 : 10)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                        .offset(x: playerService.duration > 0 ? geo.size.width * CGFloat(progress / max(playerService.duration, 1)) - (isDraggingProgress ? 7 : 5) : -5)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDraggingProgress)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            isDraggingProgress = true
                                            let pct = max(0, min(1, value.location.x / geo.size.width))
                                            progress = pct * max(playerService.duration, 1)
                                        }
                                        .onEnded { value in
                                            let pct = max(0, min(1, value.location.x / geo.size.width))
                                            playerService.seek(to: pct * max(playerService.duration, 1))
                                            isDraggingProgress = false
                                        }
                                )
                            }
                            .frame(height: 16)
                            
                            HStack {
                                Text(formatCoverFlowTime(playerService.currentTime))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text(formatCoverFlowTime(playerService.duration))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // ── Controls + Volume ─────────────────────────────
                        HStack(alignment: .center, spacing: 0) {
                            
                            // Volume bar — white on black
                            HStack(spacing: 6) {
                                Image(systemName: "speaker.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.55))
                                VolumeSlider(tintColor: .white)
                                    .frame(width: 90, height: 20)
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .padding(.leading, 24)
                            
                            Spacer()
                            
                            // Bare white icons: prev · play/pause · next
                            HStack(spacing: 28) {
                                Button(action: { playerService.previousTrack() }) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                                .buttonStyle(LiquidGlassPressStyle())
                                
                                Button(action: { playerService.togglePlayPause() }) {
                                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(LiquidGlassPressStyle())
                                
                                Button(action: { playerService.nextTrack() }) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                                .buttonStyle(LiquidGlassPressStyle())
                            }
                            .padding(.trailing, 24)
                        }
                    }
                    .padding(.bottom, 22)
                }
                .frame(width: screenWidth, height: screenHeight)
                .onAppear { progress = playerService.currentTime }
                .onReceive(playerService.$currentTime) { newTime in
                    if !isDraggingProgress { progress = newTime }
                }
                .onChange(of: playerService.currentTrackIndex) { _ in
                    isDraggingProgress = false
                    progress = 0
                }
            }
            .frame(width: screenWidth, height: screenHeight)
            .onAppear {
                initializeIndex()
            }
            .onChange(of: albums) { _ in
                initializeIndex()
            }
            // Sync cover flow when track changes externally (next/prev from mini player)
            .onChange(of: playerService.currentTrack?.id) { _ in
                if let currentTrack = playerService.currentTrack,
                   let index = albums.firstIndex(where: { $0.tracks.contains { $0.id == currentTrack.id } }) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        currentIndex = index
                    }
                }
            }
        }
    }
    
    private func initializeIndex() {
        guard !hasInitialized && !albums.isEmpty else { return }
        
        if let currentTrack = AudioPlayerService.shared.currentTrack,
           let index = albums.firstIndex(where: { $0.tracks.contains { $0.id == currentTrack.id } }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        hasInitialized = true
    }
    
    private func formatCoverFlowTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct CoverFlowCard: View {
    let album: Album
    let width: CGFloat
    let height: CGFloat
    let reflectionHeight: CGFloat
    let index: Int
    let fractionalIndex: Double
    let step: CGFloat
    @Binding var currentIndex: Int
    @Binding var selectedAlbum: Album?
    
    @State private var isHovering = false
    @State private var isFlipped = false
    @StateObject private var playerService = AudioPlayerService.shared
    
    var body: some View {
        let distance = Double(index) - fractionalIndex
        let xOffset = CGFloat(distance) * step
        let zIndex = 100.0 - abs(distance) * 10.0
        let scale = 1.0 - (min(abs(distance), 1.0) * 0.25)
        
        let isCentered = abs(distance) < 0.1
        
        let clampedDistanceForRotation = min(max(distance, -1.0), 1.0)
        let baseRotation = -clampedDistanceForRotation * 55
        let rotationAngle = baseRotation + (isFlipped ? 180 : 0)
        
        // (overlay variables kept for future use)
        
        return VStack(spacing: 0) {
            ZStack {
                if isFlipped {
                    // Back side (Tracklist)
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(album.artist)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        
                        Divider()
                            .background(Color.white.opacity(0.15))
                            .padding(.horizontal, 12)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 4) {
                                ForEach(Array(album.tracks.enumerated()), id: \.element.id) { trackIndex, track in
                                    let isCurrent = playerService.currentTrack?.id == track.id
                                    
                                    Button(action: {
                                        playerService.setPlaylist(tracks: album.tracks, startAtIndex: trackIndex)
                                    }) {
                                        HStack(spacing: 8) {
                                            Text("\(trackIndex + 1)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .white.opacity(0.5))
                                                .frame(width: 18, alignment: .trailing)
                                            
                                            Text(track.displayName)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .white)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            if isCurrent {
                                                Image(systemName: playerService.isPlaying ? "waveform" : "play.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(Color(red: 0.65, green: 0.8, blue: 0.22))
                                            }
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isCurrent ? Color.white.opacity(0.1) : Color.clear)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                            isFlipped = false
                        }
                    }
                    .frame(width: width, height: height)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.95))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                    )
                    .rotation3DEffect(.degrees(180), axis: (x: 0.0, y: 1.0, z: 0.0))
                } else {
                    // Front side (Artwork)
                    ZStack {
                        if let url = album.artworkUrl {
                            CachedAsyncImage(url: url) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image("music_thumb")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                            .frame(width: width, height: height)
                            .cornerRadius(8)
                            .clipped()
                        } else {
                            Image("music_thumb")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: height)
                                .cornerRadius(8)
                                .clipped()
                        }
                        
                        // Subtle dark overlay
                        Color.black.opacity(isCentered ? (isHovering ? 0.15 : 0.0) : 0.3)
                            .cornerRadius(8)
                    }
                    .frame(width: width, height: height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isCentered {
                            // Already centered — start playing immediately
                            if let firstTrack = album.tracks.first,
                               let globalIndex = playerService.libraryTracks.firstIndex(where: { $0.id == firstTrack.id }) {
                                playerService.setPlaylist(tracks: playerService.libraryTracks, startAtIndex: globalIndex)
                            }
                        } else {
                            // Animate to center first, then play after animation settles
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                                currentIndex = index
                            }
                            // Delay playback until the 3D centering animation has completed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
                                if let firstTrack = album.tracks.first,
                                   let globalIndex = playerService.libraryTracks.firstIndex(where: { $0.id == firstTrack.id }) {
                                    playerService.setPlaylist(tracks: playerService.libraryTracks, startAtIndex: globalIndex)
                                }
                            }
                        }
                    }
                    .onLongPressGesture {
                        if isCentered {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                isFlipped.toggle()
                            }
                        }
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovering = hovering
                        }
                    }
                }
            }
            .frame(width: width, height: height)
            .shadow(color: Color.black.opacity(0.65), radius: 10, x: 0, y: 6)
            
            // Fading Reflection
            ZStack {
                if !isFlipped {
                    let reflectionUrl = album.artworkUrl
                    if let url = reflectionUrl {
                        CachedAsyncImage(url: url) { image in
                            image.resizable()
                                 .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image("music_thumb").resizable().aspectRatio(contentMode: .fill)
                        }
                        .frame(width: width, height: height)
                        .scaleEffect(y: -1)
                        .mask(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .white.opacity(0.38),
                                    .white.opacity(0.08),
                                    .clear
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: width, height: reflectionHeight, alignment: .top)
                        .clipped()
                    } else {
                        Image("music_thumb")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: reflectionHeight)
                            .scaleEffect(y: -1)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .white.opacity(0.25),
                                        .clear
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }
            .frame(width: width, height: reflectionHeight, alignment: .top)
            .opacity(isFlipped ? 0.0 : 0.7)
        }
        .frame(width: width)
        .offset(x: xOffset)
        .scaleEffect(scale)
        .rotation3DEffect(
            .degrees(rotationAngle),
            axis: (x: 0.0, y: 1.0, z: 0.0),
            anchor: .center,
            anchorZ: 0.0,
            perspective: 0.6
        )
        .zIndex(zIndex)
        .onChange(of: isCentered) { centered in
            if !centered && isFlipped {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    isFlipped = false
                }
            }
        }
    }
}

// MARK: - Native iOS 26.1 Floating Toolbar Components

struct PlayerToolbar: View {
    @ObservedObject var playerService: AudioPlayerService
    var isSmallScreen: Bool
    
    var body: some View {
        HStack(spacing: 48) {
            Button {
                playerService.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: isSmallScreen ? 28 : 36))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                playerService.togglePlayPause()
            } label: {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: isSmallScreen ? 44 : 56))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                playerService.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: isSmallScreen ? 28 : 36))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
        }
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
                        Circle()
                            .fill(Color.blue.opacity(0.25))
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                    }
                    Circle()
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(isActive ? 0.5 : 0.15), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Subtle spring press feel for liquid glass buttons
struct LiquidGlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

extension View {
    func glassEffect() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.05), .black.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Custom Premium Progress Slider

struct PlayerProgressSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let trackWidth = geometry.size.width
            let thumbHeight: CGFloat = 14
            let thumbWidth: CGFloat = 5
            let trackHeight: CGFloat = 5
            
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: trackHeight)
                
                // Active Track — orange gradient
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.45, blue: 0.0), Color(red: 1.0, green: 0.25, blue: 0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(trackWidth * percentage, trackWidth)), height: trackHeight)
                
                // Thumb — orange with glow
                RoundedRectangle(cornerRadius: thumbWidth / 2)
                    .fill(Color.orange)
                    .overlay(
                        RoundedRectangle(cornerRadius: thumbWidth / 2)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 0.8)
                    )
                    .shadow(color: Color.orange.opacity(0.7), radius: 4, x: 0, y: 0)
                    .frame(width: thumbWidth, height: thumbHeight)
                    .offset(x: max(0, min(trackWidth * percentage - (thumbWidth / 2), trackWidth - thumbWidth)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onEditingChanged(true)
                        let locationX = gesture.location.x
                        let newPercentage = max(0, min(locationX / trackWidth, 1.0))
                        value = range.lowerBound + Double(newPercentage) * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { gesture in
                        let locationX = gesture.location.x
                        let newPercentage = max(0, min(locationX / trackWidth, 1.0))
                        value = range.lowerBound + Double(newPercentage) * (range.upperBound - range.lowerBound)
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 18)
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

extension Double {
    var formattedTimeString: String {
        guard !self.isNaN else { return "0:00" }
        let mins = Int(self) / 60
        let secs = Int(self) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Queue List View
struct QueueListView: View {
    @ObservedObject var playerService: AudioPlayerService
    let isSmallScreen: Bool
    @State private var draggedTrack: Track? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let track = playerService.currentTrack {
                HStack(spacing: 12) {
                    Group {
                        if let url = track.fullArtworkUrl {
                            CachedAsyncImage(url: url) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.clear
                            }
                        } else {
                            MusicPlaceholderView()
                        }
                    }
                    .frame(width: 54, height: 54)
                    .cornerRadius(8)
                    .clipped()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.displayName).font(.headline).fontWeight(.semibold).foregroundColor(.white).lineLimit(1)
                        Text(track.displayArtist).font(.subheadline).foregroundColor(.white.opacity(0.7)).lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, isSmallScreen ? 12 : 24)
                .padding(.bottom, 20)
            }
            
            // 3 Action Buttons
            HStack(spacing: 12) {
                QueueActionButton(icon: "shuffle", isActive: playerService.isShuffleEnabled) {
                    playerService.toggleShuffle()
                }
                QueueActionButton(icon: playerService.isRepeatEnabled ? "repeat.1" : "repeat", isActive: playerService.isRepeatEnabled) {
                    playerService.toggleRepeat()
                }
                QueueActionButton(icon: "infinity", isActive: playerService.isAutoPlayEnabled) {
                    playerService.toggleAutoPlay()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            // Queue List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text("Continue Playing")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)
                    
                    let nextIndex = (playerService.currentTrackIndex ?? -1) + 1
                    if nextIndex < playerService.tracks.count {
                        let upcomingTracks = playerService.tracks[nextIndex...]
                        ForEach(Array(upcomingTracks.enumerated()), id: \.offset) { offset, track in
                            let absoluteIndex = nextIndex + offset
                            HStack(spacing: 16) {
                                Group {
                                    if let url = track.fullArtworkUrl {
                                        CachedAsyncImage(url: url) { image in
                                            image.resizable()
                                                 .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.clear
                                        }
                                    } else {
                                        MusicPlaceholderView()
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .cornerRadius(6)
                                .clipped()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.displayName).font(.callout).foregroundColor(.white).lineLimit(1)
                                    Text(track.displayArtist).font(.caption).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 24)
                            .onTapGesture {
                                playerService.playTrack(at: absoluteIndex)
                            }
                            .onDrag {
                                self.draggedTrack = track
                                return NSItemProvider(object: track.id as NSString)
                            }
                            .onDrop(of: [.text], delegate: QueueDropDelegate(item: track, playerService: playerService, draggedItem: $draggedTrack))
                        }
                    } else {
                        Text("No upcoming tracks")
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct QueueActionButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isActive ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isActive ? Color.white.opacity(0.9) : Color.white.opacity(0.15))
                .cornerRadius(12)
        }
    }
}

// MARK: - Portrait Bottom Controls View
struct PortraitBottomControlsView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var progress: Double
    @Binding var isDraggingSlider: Bool
    @Binding var isShowingQueue: Bool
    let isSmallScreen: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 12)
            
            // Progress Slider
            VStack(spacing: 6) {
                PlayerProgressSlider(
                    value: $progress,
                    range: 0...max(playerService.duration, 1),
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            playerService.seek(to: progress)
                        }
                    }
                )
                .frame(height: 20)
                
                HStack {
                    Text(playerService.currentTime.formattedTimeString)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("-" + (playerService.duration - playerService.currentTime).formattedTimeString)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer().frame(height: 24)
            
            // Playback Controls
            HStack {
                Spacer()
                PlayerToolbar(playerService: playerService, isSmallScreen: isSmallScreen)
                Spacer()
            }
            
            Spacer().frame(height: 24)
            
            // Volume Control
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 16, height: 16)
                
                VolumeSlider(tintColor: .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 4)
            
            Spacer().frame(height: 24)
            
            // Bottom Toolbar (Airplay, Queue)
            HStack {
                AirPlayView()
                    .frame(width: 44, height: 44)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        isShowingQueue.toggle()
                    }
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isShowingQueue ? .black : .white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(isShowingQueue ? Color.white.opacity(0.9) : Color.clear)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, isSmallScreen ? 12 : 24)
    }
}

// MARK: - AirPlay View
struct AirPlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        routePickerView.activeTintColor = .white
        routePickerView.tintColor = .white
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}


struct QueueDropDelegate: DropDelegate {
    let item: Track
    let playerService: AudioPlayerService
    @Binding var draggedItem: Track?
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        if draggedItem != item {
            guard let from = playerService.tracks.firstIndex(of: draggedItem),
                  let to = playerService.tracks.firstIndex(of: item) else { return }
            
            withAnimation {
                playerService.tracks.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                
                // Keep playing track index aligned
                if let currentIndex = playerService.currentTrackIndex {
                    if currentIndex == from {
                        playerService.currentTrackIndex = to
                    } else if from < currentIndex && to >= currentIndex {
                        playerService.currentTrackIndex = currentIndex - 1
                    } else if from > currentIndex && to <= currentIndex {
                        playerService.currentTrackIndex = currentIndex + 1
                    }
                }
            }
        }
    }
}
