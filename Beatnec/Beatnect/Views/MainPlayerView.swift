import SwiftUI

struct MainPlayerView: View {
    @StateObject private var apiService = APIService.shared
    @StateObject private var playerService = AudioPlayerService.shared
    
    @State private var serverInput: String = ""
    @State private var documentInput: String = ""
    @State private var searchInput: String = ""
    @State private var errorMessage: String?
    @State private var isShowingSettings = false
    @State private var isShowingPlayerDetail = false
    
    // Grid layout for recent items
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var filteredTracks: [Track] {
        if searchInput.isEmpty {
            return playerService.tracks
        } else {
            return playerService.tracks.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchInput) ||
                $0.displayArtist.localizedCaseInsensitiveContains(searchInput)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Artists, Songs, Lyrics, and More", text: $searchInput)
                                    .font(.system(size: 16, design: .rounded))
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding(10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Recently Added / Featured section
                            if !playerService.tracks.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Recently Added")
                                        .font(.system(.title2, design: .rounded))
                                        .fontWeight(.bold)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(Array(playerService.tracks.prefix(5).enumerated()), id: \.element.id) { index, track in
                                                Button(action: {
                                                    playerService.setPlaylist(tracks: playerService.tracks, startAtIndex: index)
                                                }) {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        // Artwork Tile
                                                        if let artworkUrlString = track.artworkUrl, let url = URL(string: artworkUrlString) {
                                                            AsyncImage(url: url) { image in
                                                                image.resizable()
                                                                     .aspectRatio(contentMode: .fill)
                                                            } placeholder: {
                                                                Color(.secondarySystemBackground)
                                                            }
                                                            .frame(width: 140, height: 140)
                                                            .cornerRadius(12)
                                                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                                                            .clipped()
                                                        } else {
                                                            Image(systemName: "music.note")
                                                                .font(.system(size: 40))
                                                                .foregroundColor(.secondary)
                                                                .frame(width: 140, height: 140)
                                                                .background(Color(.secondarySystemGroupedBackground))
                                                                .cornerRadius(12)
                                                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                                                        }
                                                        
                                                        Text(track.displayName)
                                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                                            .foregroundColor(.primary)
                                                            .lineLimit(1)
                                                            .frame(width: 140, alignment: .leading)
                                                        
                                                        Text(track.displayArtist)
                                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                            .frame(width: 140, alignment: .leading)
                                                    }
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Library List section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("All Tracks")
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                if filteredTracks.isEmpty {
                                    VStack(spacing: 12) {
                                        Spacer()
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 48))
                                            .foregroundColor(.secondary)
                                        Text("No Music Available")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                        Text("Verify server address in Settings")
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                                            Button(action: {
                                                playerService.setPlaylist(tracks: playerService.tracks, startAtIndex: index)
                                            }) {
                                                VStack(spacing: 0) {
                                                    TrackRowView(track: track,
                                                                 isCurrent: playerService.currentTrackIndex == index,
                                                                 isPlaying: playerService.isPlaying)
                                                        .padding(.horizontal)
                                                        .padding(.vertical, 8)
                                                        .background(Color(.secondarySystemGroupedBackground))
                                                    
                                                    if index < filteredTracks.count - 1 {
                                                        Divider()
                                                            .padding(.leading, 72)
                                                    }
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    // Floating Apple-Style Mini Player Pill
                    if let currentTrack = playerService.currentTrack {
                        MiniPlayerBar(track: currentTrack,
                                      isPlaying: playerService.isPlaying,
                                      onToggle: { playerService.togglePlayPause() },
                                      onTap: { isShowingPlayerDetail = true })
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle("Listen Now")
            .navigationBarItems(
                leading: Button(action: reloadLibrary) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.pink)
                },
                trailing: Button(action: { isShowingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.pink)
                }
            )
            .sheet(isPresented: $isShowingSettings) {
                SettingsSheetView(serverInput: $serverInput, documentInput: $documentInput, isPresented: $isShowingSettings, onSave: saveServerSettings)
            }
            .sheet(isPresented: $isShowingPlayerDetail) {
                PlayerDetailView(playerService: playerService, isPresented: $isShowingPlayerDetail)
            }
        }
        .accentColor(.pink) // Apple Music style Pink tint
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            serverInput = apiService.serverAddress
            documentInput = apiService.documentName
            reloadLibrary()
        }
    }
    
    private func reloadLibrary() {
        apiService.fetchTracks { result in
            switch result {
            case .success(let tracks):
                playerService.tracks = tracks
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

// MARK: - Floating Apple-Style Mini Player Pill

struct MiniPlayerBar: View {
    let track: Track
    let isPlaying: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkUrlString = track.artworkUrl, let url = URL(string: artworkUrlString) {
                AsyncImage(url: url) { image in
                    image.resizable()
                         .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 42, height: 42)
                .cornerRadius(6)
                .clipped()
            } else {
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
                    .frame(width: 42, height: 42)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(6)
            }
            
            // Track Info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                
                Text(track.displayArtist)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play / Pause controls
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                }
                
                Button(action: { AudioPlayerService.shared.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color(.secondarySystemGroupedBackground)
                .opacity(0.95)
                .background(.ultraThinMaterial)
        )
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
        .onTapGesture(perform: onTap)
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
                .foregroundColor(.pink)
                .fontWeight(.bold)
            )
        }
    }
}

// MARK: - Player Detail View

struct PlayerDetailView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var isPresented: Bool
    
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    @State private var animateBackground = false
    
    var body: some View {
        ZStack {
            // Apple Music Animated Mesh/Glow Background
            ZStack {
                Color(.black)
                    .ignoresSafeArea()
                
                if let track = playerService.currentTrack, let artworkUrlString = track.artworkUrl, let url = URL(string: artworkUrlString) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.clear
                    }
                    .blur(radius: 40)
                    .opacity(0.35)
                    .ignoresSafeArea()
                }
                
                // Breath glow effects
                Circle()
                    .fill(Color.pink.opacity(0.18))
                    .frame(width: 380, height: 380)
                    .offset(x: animateBackground ? -80 : 80, y: animateBackground ? -120 : 120)
                    .blur(radius: 80)
                
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 320, height: 320)
                    .offset(x: animateBackground ? 100 : -100, y: animateBackground ? 80 : -80)
                    .blur(radius: 60)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                    animateBackground.toggle()
                }
            }
            
            // Content
            VStack {
                // Drag handle bar
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 16)
                
                Spacer()
                
                // Apple Music Tactile Scaling Card
                if let track = playerService.currentTrack {
                    VStack(spacing: 0) {
                        if let artworkUrlString = track.artworkUrl, let url = URL(string: artworkUrlString) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                                     .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(maxWidth: 300, maxHeight: 300)
                            .cornerRadius(18)
                            .shadow(color: playerService.isPlaying ? Color.pink.opacity(0.4) : Color.black.opacity(0.4),
                                    radius: playerService.isPlaying ? 28 : 12,
                                    x: 0,
                                    y: playerService.isPlaying ? 16 : 8)
                            .scaleEffect(playerService.isPlaying ? 1.0 : 0.82)
                            .animation(.spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0), value: playerService.isPlaying)
                        } else {
                            Image(systemName: "music.note")
                                 .font(.system(size: 80))
                                 .foregroundColor(.secondary)
                                 .frame(width: 250, height: 250)
                                 .background(Color(.systemGray6))
                                 .cornerRadius(18)
                                 .shadow(radius: 10)
                                 .scaleEffect(playerService.isPlaying ? 1.0 : 0.82)
                                 .animation(.spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0), value: playerService.isPlaying)
                        }
                    }
                    .frame(height: 320)
                    
                    // Metadata & Explicit badges
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.displayName)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(track.displayArtist)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            // Apple style Dolby/Lossless tags
                            HStack(spacing: 6) {
                                Text("Lossless")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(4)
                                
                                Text("Dolby Atmos")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(4)
                            }
                            .padding(.top, 4)
                        }
                        
                        Spacer()
                        
                        // Menu Button
                        Button(action: {}) {
                            Image(systemName: "ellipsis.circle.fill")
                                 .font(.system(size: 26))
                                 .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                }
                
                Spacer()
                
                // Seek Slider
                VStack(spacing: 8) {
                    Slider(value: Binding(get: {
                        isDraggingSlider ? sliderValue : playerService.currentTime
                    }, set: { newValue in
                        sliderValue = newValue
                    }), in: 0...max(playerService.duration, 1), onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            playerService.seek(to: sliderValue)
                        }
                    })
                    .accentColor(.white)
                    
                    HStack {
                        Text(formatTime(playerService.currentTime))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(playerService.duration))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                
                // Audio Transport Controls
                HStack(spacing: 48) {
                    // Backward
                    Button(action: { playerService.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    
                    // Play / Pause Circle
                    Button(action: { playerService.togglePlayPause() }) {
                        Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 42))
                            .foregroundColor(.white)
                            .frame(width: 88, height: 88)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(44)
                    }
                    
                    // Forward
                    Button(action: { playerService.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 16)
                
                Spacer()
                
                // Volume Controls (Apple Music style speaker keys)
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    
                    Slider(value: Binding(
                        get: { Double(playerService.volume) },
                        set: { playerService.volume = Float($0) }
                    ), in: 0...1)
                    .accentColor(.white)
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Subaction Bottom Bar (Lyrics, AirPlay, Queue)
                HStack(spacing: 64) {
                    Button(action: {}) {
                        Image(systemName: "quote.bubble")
                             .font(.system(size: 18))
                             .foregroundColor(.secondary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "airplayaudio")
                             .font(.system(size: 20))
                             .foregroundColor(.secondary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "list.bullet")
                             .font(.system(size: 18))
                             .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 24)
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
