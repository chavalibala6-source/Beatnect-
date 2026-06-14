import SwiftUI
import MediaPlayer
import Combine


struct MainPlayerView: View {
    @StateObject private var apiService = APIService.shared
    @StateObject private var playerService = AudioPlayerService.shared
    
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
                    // Premium Black Background
                    Color.black
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
                                    .font(.system(.headline, design: .rounded))
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
                            if verticalSizeClass == .compact {
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
                                        .padding(.bottom, playerService.currentTrack != nil ? 90 : 16) // Padding for floating MiniPlayerBar
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
            // Bottom Bar with Home Button and Compact Mini Player
            if verticalSizeClass != .compact {
                HStack(spacing: 12) {
                    // Home Button (with glass effect)
                    Button(action: {
                        scrollToTopTrigger.toggle()
                        reloadLibrary()
                    }) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1.0)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 16)
                    
                    if let currentTrack = playerService.currentTrack {
                        MiniPlayerBar(track: currentTrack,
                                      isPlaying: playerService.isPlaying,
                                      onToggle: { playerService.togglePlayPause() },
                                      onTap: { isShowingPlayerDetail = true })
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
        }
        .fullScreenCover(isPresented: $isShowingPlayerDetail) {
            PlayerDetailView(playerService: playerService, isPresented: $isShowingPlayerDetail)
        }
        .onAppear {
            serverInput = apiService.serverAddress
            documentInput = apiService.documentName
            reloadLibrary()
        }
        .preferredColorScheme(.dark)
    }
    
    private var albums: [Album] {
        var dict = [String: Album]()
        for track in playerService.libraryTracks {
            let albumName = track.displayAlbum
            let albumArtist = track.displayArtist
            let key = "\(albumName)|\(albumArtist)"
            
            if var existingAlbum = dict[key] {
                existingAlbum.tracks.append(track)
                dict[key] = existingAlbum
            } else {
                dict[key] = Album(
                    name: albumName,
                    artist: albumArtist,
                    artworkUrl: track.fullArtworkUrl,
                    tracks: [track]
                )
            }
        }
        return dict.values.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
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
    
    @State private var isFlipped = false
    @State private var isHovering = false
    @StateObject private var playerService = AudioPlayerService.shared
    
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
        let rotationAngle = isFlipped ? 180.0 : 0.0
        
        return ZStack {
            if isFlipped {
                backView
            } else {
                frontView
            }
        }
        .rotation3DEffect(Angle(degrees: rotationAngle), axis: (x: 0.0, y: 1.0, z: 0.0))
    }
    
    private var backView: some View {
        VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(album.artist)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                isFlipped = false
                            }
                        }) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 22, height: 22)
                                .background(.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    
                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 10)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(Array(album.tracks.enumerated()), id: \.element.id) { trackIndex, track in
                                let isTrackCurrent = playerService.currentTrack?.id == track.id
                                
                                Button(action: {
                                    if let globalIndex = playerService.libraryTracks.firstIndex(where: { $0.id == track.id }) {
                                        playerService.setPlaylist(tracks: playerService.libraryTracks, startAtIndex: globalIndex)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Text("\(trackIndex + 1)")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(isTrackCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .white.opacity(0.5))
                                            .frame(width: 14, alignment: .trailing)
                                        
                                        Text(track.displayName)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(isTrackCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .white)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        if isTrackCurrent {
                                            Image(systemName: playerService.isPlaying ? "waveform" : "play.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(Color(red: 0.65, green: 0.8, blue: 0.22))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isTrackCurrent ? Color.white.opacity(0.1) : Color.clear)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1.0)
        )
        .rotation3DEffect(Angle(degrees: 180), axis: (x: 0.0, y: 1.0, z: 0.0))
    }
    
    @ViewBuilder
    private var artworkView: some View {
        if let url = album.artworkUrl {
            CachedAsyncImage(url: url) { image in
                image.resizable()
                     .aspectRatio(contentMode: .fit)
                     .frame(maxWidth: .infinity)
                     .frame(height: 140)
            } placeholder: {
                Rectangle()
                     .fill(Color.white.opacity(0.05))
                     .overlay(ProgressView())
                     .frame(maxWidth: .infinity)
                     .frame(height: 140)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(Color.black)
            .cornerRadius(12)
            .clipped()
        } else {
            Rectangle()
                .fill(Color(.secondarySystemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .cornerRadius(12)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                )
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
        .frame(height: 140)
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
                    .stroke(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.8) : Color.white.opacity(0.12), lineWidth: 1.5)
            )
            .shadow(color: (isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : Color.black).opacity(isCurrent ? 0.2 : 0.12), radius: 8, x: 0, y: 4)
            
            // Text Details
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(album.artist)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isCurrent ? Color(red: 0.72, green: 0.62, blue: 0.16) : .secondary)
                    .lineLimit(1)
                
                Text("\(album.tracks.count) Songs")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrent ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1.0)
        )
        .scaleEffect(isCurrent ? 1.02 : 1.0)
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
        .onLongPressGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                isFlipped.toggle()
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Artwork
                if let url = track.fullArtworkUrl {
                    CachedAsyncImage(url: url) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                             .frame(width: 48, height: 48)
                    } placeholder: {
                        ProgressView()
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
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(track.displayArtist)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Settings Sheet

struct SettingsSheetView: View {
    @Binding var serverInput: String
    @Binding var documentInput: String
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
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
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var isDraggingSlider = false
    @State private var progress: Double = 0
    
    var body: some View {
        let artworkScale = playerService.isPlaying ? 1.08 : 1.0
        let artworkShadowRadius = playerService.isPlaying ? 15.0 : 8.0
        let artworkShadowOpacity = playerService.isPlaying ? 0.45 : 0.25
        
        return GeometryReader { geometry in
            let isSmallScreen = geometry.size.height < 720
            
            ZStack {
                // Swipe-to-dismiss gesture overlay on empty spaces
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.height > 60 {
                                    withAnimation {
                                        isPresented = false
                                    }
                                }
                            }
                    )
                
                if verticalSizeClass == .compact {
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
                                        if let url = track.fullArtworkUrl {
                                            // Glowing Artwork Drop Shadow (Blurred and offset copy of the artwork)
                                            CachedAsyncImage(url: url) { image in
                                                 image.resizable()
                                                      .aspectRatio(contentMode: .fit)
                                                      .frame(maxHeight: landscapeArtworkSize)
                                             } placeholder: {
                                                 ProgressView()
                                                     .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                             }
                                            .frame(maxHeight: landscapeArtworkSize)
                                            .scaleEffect(artworkScale)
                                            .blur(radius: playerService.isPlaying ? 24 : 16)
                                            .opacity(playerService.isPlaying ? 0.75 : 0.4)
                                            .offset(y: playerService.isPlaying ? 12 : 6)
                                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                                            
                                            // Main Artwork image
                                            CachedAsyncImage(url: url) { image in
                                                image.resizable()
                                                     .aspectRatio(contentMode: .fit)
                                                     .frame(maxHeight: landscapeArtworkSize)
                                            } placeholder: {
                                                ProgressView()
                                                    .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                            }
                                            .frame(maxHeight: landscapeArtworkSize)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [.white.opacity(0.35), .clear, .black.opacity(0.2)]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1.5
                                                    )
                                            )
                                            .scaleEffect(artworkScale)
                                            .shadow(color: Color.black.opacity(artworkShadowOpacity), radius: artworkShadowRadius, x: 0, y: playerService.isPlaying ? 10 : 5)
                                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                                        } else {
                                            Image(systemName: "music.note")
                                                .font(.system(size: landscapeArtworkSize * 0.27))
                                                .foregroundColor(.secondary)
                                                .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                                .background(Color(.secondarySystemBackground))
                                                .cornerRadius(16)
                                                .shadow(radius: 8)
                                        }
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
                                        ScrollingTextView(text: track.displayName, font: .title3, fontWeight: .bold, isCentered: false)
                                        
                                        Text(track.displayArtist)
                                            .font(.subheadline)
                                            .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                                            .lineLimit(1)
                                    }
                                    .padding(.top, 4)
                                }
                                
                                Spacer(minLength: 8)
                                
                                // Waveform Visualizer for Landscape
                                WaveformVisualizer(isPlaying: playerService.isPlaying)
                                    .frame(height: 18)
                                    .padding(.vertical, 2)
                                
                                Spacer(minLength: 14)
                                
                                // Progress Slider
                                VStack(spacing: 4) {
                                    Slider(value: $progress, in: 0...max(playerService.duration, 1), onEditingChanged: { editing in
                                        isDraggingSlider = editing
                                        if !editing {
                                            playerService.seek(to: progress)
                                        }
                                    })
                                    .accentColor(Color(red: 0.65, green: 0.8, blue: 0.22))
                                    
                                    HStack {
                                        Text(formatTime(playerService.currentTime))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(formatTime(playerService.duration))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
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
                                        .foregroundColor(.secondary)
                                    
                                    VolumeSlider()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 22)
                                    
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
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
                            .padding(.top, isSmallScreen ? 8 : 16)
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
                        
                        Spacer(minLength: isSmallScreen ? 6 : 12)
                        
                        // Big Artwork Vinyl
                        if let track = playerService.currentTrack {
                            ZStack {
                                if let url = track.fullArtworkUrl {
                                    // Glowing Artwork Drop Shadow (Blurred and offset copy of the artwork)
                                    CachedAsyncImage(url: url) { image in
                                        image.resizable()
                                             .aspectRatio(contentMode: .fit)
                                             .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                    } placeholder: {
                                        Color.clear
                                            .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                    }
                                    .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                    .scaleEffect(artworkScale)
                                    .blur(radius: playerService.isPlaying ? 28 : 16)
                                    .opacity(playerService.isPlaying ? 0.75 : 0.4)
                                    .offset(y: playerService.isPlaying ? 16 : 8)
                                    .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                                    
                                    // Main Artwork image
                                    CachedAsyncImage(url: url) { image in
                                        image.resizable()
                                             .aspectRatio(contentMode: .fit)
                                             .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                    } placeholder: {
                                        ProgressView()
                                             .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                    }
                                    .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [.white.opacity(0.35), .clear, .black.opacity(0.25)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .scaleEffect(artworkScale)
                                    .shadow(color: Color.black.opacity(artworkShadowOpacity), radius: artworkShadowRadius, x: 0, y: playerService.isPlaying ? 12 : 6)
                                    .animation(.spring(response: 0.45, dampingFraction: 0.7), value: playerService.isPlaying)
                                } else {
                                    Image(systemName: "music.note")
                                        .font(.system(size: portraitArtworkSize * 0.27))
                                        .foregroundColor(.secondary)
                                        .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(20)
                                        .shadow(radius: 10)
                                }
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
                        
                        Spacer(minLength: isSmallScreen ? 12 : 24)
                        
                        // Floating Liquid Glass-Morphic Card for Controls
                        VStack(spacing: 0) {
                            if let track = playerService.currentTrack {
                                VStack(spacing: 4) {
                                    ScrollingTextView(text: track.displayName, font: isSmallScreen ? .headline : .title2, fontWeight: .bold, isCentered: true)
                                        .padding(.horizontal)
                                    
                                    Text(track.displayArtist)
                                        .font(isSmallScreen ? .subheadline : .headline)
                                        .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                                }
                                .padding(.top, isSmallScreen ? 12 : 18)
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
                            
                            // Waveform Visualizer
                            WaveformVisualizer(isPlaying: playerService.isPlaying)
                                .frame(height: isSmallScreen ? 24 : 32)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 4)
                            
                            Spacer()
                            
                            // Progress Slider
                            VStack(spacing: isSmallScreen ? 4 : 8) {
                                Slider(value: $progress, in: 0...max(playerService.duration, 1), onEditingChanged: { editing in
                                    isDraggingSlider = editing
                                    if !editing {
                                        playerService.seek(to: progress)
                                    }
                                })
                                .accentColor(Color(red: 0.65, green: 0.8, blue: 0.22))
                                
                                HStack {
                                    Text(formatTime(playerService.currentTime))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatTime(playerService.duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            Spacer()
                            
                             // Playback Controls (Row 1)
                             HStack {
                                 Spacer()
                                 PlayerToolbar(playerService: playerService, isSmallScreen: isSmallScreen)
                                 Spacer()
                             }
                             Spacer()
                            
                            // Volume Control (Row 2, replacing Shuffle & Repeat)
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: "speaker.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                                
                                VolumeSlider()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 22)
                                
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .padding(.horizontal, 4)
                            
                            Spacer()
                            
                            // Shuffle & Repeat Controls (Row 3, at the end)
                            HStack(spacing: isSmallScreen ? 48 : 64) {
                                Spacer()
                                // Shuffle
                                Button(action: { playerService.toggleShuffle() }) {
                                    Image(systemName: "shuffle")
                                }
                                .buttonStyle(LiquidGlassButtonStyle(isActive: playerService.isShuffleEnabled, activeColor: .teal, size: isSmallScreen ? 34 : 40))
                                
                                // Repeat
                                Button(action: { playerService.toggleRepeat() }) {
                                    Image(systemName: playerService.isRepeatEnabled ? "repeat.1" : "repeat")
                                }
                                .buttonStyle(LiquidGlassButtonStyle(isActive: playerService.isRepeatEnabled, activeColor: .purple, size: isSmallScreen ? 34 : 40))
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, isSmallScreen ? 8 : 16)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
        .background(
            Color.black
                .ignoresSafeArea()
        )
        .onAppear {
            progress = playerService.currentTime
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
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Scrolling Text View

struct ScrollingTextView: View {
    let text: String
    var font: Font = .body
    var fontWeight: Font.Weight = .bold
    var color: Color = .primary
    var isCentered: Bool = true
    
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
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        
        // Custom styling for the volume slider to match Apple Music design (solid white and translucent white)
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                slider.minimumTrackTintColor = .white
                slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.28)
                slider.thumbTintColor = .white
                break
            }
        }
        
        return volumeView
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
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

// MARK: - Waveform Visualizer View

struct WaveformVisualizer: View {
    let isPlaying: Bool
    @State private var phase: CGFloat = 0.0
    
    // Timer to drive the fluid animation
    let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 3.0
            let gap: CGFloat = 2.0
            let count = Int(size.width / (barWidth + gap))
            
            for i in 0..<count {
                let x = CGFloat(i) * (barWidth + gap) + barWidth / 2.0
                
                // Normal curve envelope so it shapes like a wave (tapers at ends)
                let relativeX = CGFloat(i) / CGFloat(count)
                let envelope = sin(relativeX * .pi)
                
                // Fluid wavy movement driven by phase
                let waveMod: CGFloat
                if isPlaying {
                    waveMod = sin(relativeX * 10.0 + phase) * 0.35 + cos(relativeX * 6.0 - phase) * 0.25 + 0.6
                } else {
                    waveMod = 0.12 // Tiny pulse resting state
                }
                
                let barHeight = size.height * envelope * waveMod
                let y = (size.height - barHeight) / 2.0
                
                let path = Path(roundedRect: CGRect(x: x - barWidth/2.0, y: y, width: barWidth, height: barHeight), cornerRadius: barWidth/2.0)
                
                // Colored glow matches the theme (lime-green)
                let color = Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.85)
                context.fill(path, with: .color(color))
            }
        }
        .onReceive(timer) { _ in
            if isPlaying {
                withAnimation(.linear(duration: 0.08)) {
                    phase += 0.45
                }
            }
        }
    }
}

// MARK: - 3D Cover Flow Views (iOS 6 Style)

struct CoverFlowView: View {
    let albums: [Album]
    @Binding var selectedAlbum: Album?
    
    @State private var currentIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var hasInitialized = false
    
    // Configurations for larger sizing
    let coverWidth: CGFloat = 260
    let coverHeight: CGFloat = 260
    let reflectionHeight: CGFloat = 100
    
    // Spacing step between cards (uniform gap)
    let step: CGFloat = 220 // was 160 (try 200–240 to taste)
    
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
                    .frame(height: screenHeight * 0.48)
                }
                .ignoresSafeArea(edges: .bottom)
                
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
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.width
                            var offsetIndex = -Int(round(value.translation.width / step))
                            
                            // Boost with velocity for swiping
                            if velocity < -100 {
                                offsetIndex = max(offsetIndex, 1)
                            } else if velocity > 100 {
                                offsetIndex = min(offsetIndex, -1)
                            }
                            
                            let newIndex = min(albums.count - 1, max(0, currentIndex + offsetIndex))
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                currentIndex = newIndex
                            }
                        }
                )
            }
            .frame(width: screenWidth, height: screenHeight)
            .onAppear {
                initializeIndex()
            }
            .onChange(of: albums) { _ in
                initializeIndex()
            }
        }
    }
    
    private func initializeIndex() {
        guard !hasInitialized && !albums.isEmpty else { return }
        
        // Center on the album of the currently playing track if it exists, otherwise default to first album on left
        if let currentTrack = AudioPlayerService.shared.currentTrack,
           let index = albums.firstIndex(where: { $0.tracks.contains { $0.id == currentTrack.id } }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        hasInitialized = true
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
    
    @State private var isFlipped = false
    @State private var isHovering = false
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
        
        let playButtonSize: CGFloat = isCentered ? 54 : 40
        let playIconSize: CGFloat = isCentered ? 26 : 18
        let infoButtonSize: CGFloat = isCentered ? 36 : 28
        let infoIconSize: CGFloat = isCentered ? 20 : 14
        let overlayOpacity: Double = isCentered ? 1.0 : 0.8
        
        return VStack(spacing: 0) {
            ZStack {
                if isFlipped {
                    // Back side (Tracklist)
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.name)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(album.artist)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                    isFlipped = false
                                }
                            }) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 28, height: 28)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
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
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .white.opacity(0.5))
                                                .frame(width: 18, alignment: .trailing)
                                            
                                            Text(track.displayName)
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
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
                                     .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(ProgressView())
                            }
                            .frame(width: width, height: height)
                            .background(Color.black)
                            .cornerRadius(8)
                            .clipped()
                        } else {
                            Rectangle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: width, height: height)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 54))
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                        // Subtle dark overlay
                        Color.black.opacity(isCentered ? (isHovering ? 0.15 : 0.0) : 0.3)
                            .cornerRadius(8)
                    }
                    .frame(width: width, height: height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            if isCentered {
                                if let firstTrack = album.tracks.first,
                                   let globalIndex = playerService.libraryTracks.firstIndex(where: { $0.id == firstTrack.id }) {
                                    playerService.setPlaylist(tracks: playerService.libraryTracks, startAtIndex: globalIndex)
                                }
                            } else {
                                currentIndex = index
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
                    if let url = album.artworkUrl {
                        CachedAsyncImage(url: url) { image in
                            image.resizable()
                                 .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.clear
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
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
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
        HStack(spacing: 24) {
            Button {
                playerService.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(GlassButtonStyle(isActive: false, size: isSmallScreen ? 40 : 48))

            Button {
                playerService.togglePlayPause()
            } label: {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(GlassButtonStyle(isActive: playerService.isPlaying, size: isSmallScreen ? 48 : 58))

            Button {
                playerService.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(GlassButtonStyle(isActive: false, size: isSmallScreen ? 40 : 48))
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                    .offset(x: playerService.isPlaying ? -20 : -40, y: 0)
                
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .blur(radius: 20)
                    .offset(x: playerService.isPlaying ? 20 : 40, y: 0)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: playerService.isPlaying)
        )
    }
}

struct GlassButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var size: CGFloat = 44
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundColor(.white)
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
                
                // Active Track (White)
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.white)
                    .frame(width: max(0, min(trackWidth * percentage, trackWidth)), height: trackHeight)
                
                // Custom Vertical Capsule Thumb (like the image)
                RoundedRectangle(cornerRadius: thumbWidth / 2)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: thumbWidth / 2)
                            .stroke(Color.black.opacity(0.35), lineWidth: 0.8)
                    )
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
