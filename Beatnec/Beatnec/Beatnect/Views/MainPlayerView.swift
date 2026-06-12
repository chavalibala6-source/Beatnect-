import SwiftUI
import MediaPlayer

struct MainPlayerView: View {
    @StateObject private var apiService = APIService.shared
    @StateObject private var playerService = AudioPlayerService.shared
    
    @State private var serverInput: String = ""
    @State private var documentInput: String = ""
    @State private var errorMessage: String?
    @State private var isShowingSettings = false
    @State private var isShowingPlayerDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Library Listing
                    if playerService.tracks.isEmpty {
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
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(playerService.tracks.enumerated()), id: \.element.id) { index, track in
                                    Button(action: {
                                        playerService.setPlaylist(tracks: playerService.tracks, startAtIndex: index)
                                    }) {
                                        TrackRowView(track: track,
                                                     isCurrent: playerService.currentTrackIndex == index,
                                                     isPlaying: playerService.isPlaying)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    
                    // Mini Player Bar (Persistent at bottom)
                    if let currentTrack = playerService.currentTrack {
                        MiniPlayerBar(track: currentTrack,
                                      isPlaying: playerService.isPlaying,
                                      onToggle: { playerService.togglePlayPause() },
                                      onTap: { isShowingPlayerDetail = true })
                    }
                }
            }
            .navigationTitle("Beatnect")
            .navigationBarItems(
                leading: Button(action: reloadLibrary) {
                    Image(systemName: "arrow.clockwise")
                },
                trailing: Button(action: { isShowingSettings = true }) {
                    Image(systemName: "gearshape")
                }
            )
            .sheet(isPresented: $isShowingSettings) {
                SettingsSheetView(serverInput: $serverInput, documentInput: $documentInput, isPresented: $isShowingSettings, onSave: saveServerSettings)
            }
            .fullScreenCover(isPresented: $isShowingPlayerDetail) {
                PlayerDetailView(playerService: playerService, isPresented: $isShowingPlayerDetail)
            }
        }
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

// MARK: - Mini Player Bar

struct MiniPlayerBar: View {
    let track: Track
    let isPlaying: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let url = track.fullArtworkUrl {
                AsyncImage(url: url) { image in
                    image.resizable()
                         .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
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
            
            // Info
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
            
            // Play/Pause Button
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color(.tertiarySystemBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: -4)
        )
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
    @State private var sliderValue: Double = 0
    
    var body: some View {
        ZStack {
            // Blurred Artwork Background (Ignores safe areas to provide complete screen coverage like Apple Music)
            if let track = playerService.currentTrack, let url = track.fullArtworkUrl {
                AsyncImage(url: url) { image in
                    image.resizable()
                         .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .blur(radius: 40)
                .opacity(0.4)
                .ignoresSafeArea()
            }
            
            // Foreground Content (Respects safe areas automatically)
            GeometryReader { geometry in
                let isSmallScreen = geometry.size.height < 720
                
                if verticalSizeClass == .compact {
                    // Landscape Layout: Image left side, controls right side
                    ZStack(alignment: .topLeading) {
                        // Dismiss button for Landscape fullScreenCover
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(10)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        .zIndex(1)
                        
                        let landscapeArtworkSize = max(120.0, min(220.0, geometry.size.height - 48.0))
                        
                        HStack(spacing: 24) {
                            // Left Side: Artwork Vinyl
                            if let track = playerService.currentTrack {
                                if let url = track.fullArtworkUrl {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                             .aspectRatio(contentMode: .fit)
                                             .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                    } placeholder: {
                                        ProgressView()
                                            .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                    }
                                    .frame(width: landscapeArtworkSize, height: landscapeArtworkSize)
                                    .cornerRadius(16)
                                    .shadow(radius: 12)
                                    .rotationEffect(Angle(degrees: playerService.isPlaying ? 360 : 0))
                                    .animation(playerService.isPlaying ? Animation.linear(duration: 25).repeatForever(autoreverses: false) : .default, value: playerService.isPlaying)
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
                            
                            // Right Side: Controls and Info
                            VStack(alignment: .leading, spacing: 8) {
                                Spacer(minLength: 4)
                                
                                if let track = playerService.currentTrack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.displayName)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .lineLimit(1)
                                        
                                        Text(track.displayArtist)
                                            .font(.subheadline)
                                            .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                                            .lineLimit(1)
                                    }
                                }
                                
                                // Progress Slider
                                VStack(spacing: 4) {
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
                                
                                // Player Controls
                                HStack(spacing: 16) {
                                    // Shuffle
                                    Button(action: { playerService.toggleShuffle() }) {
                                        Image(systemName: "shuffle")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(playerService.isShuffleEnabled ? .blue : .primary)
                                            .frame(width: 32, height: 32)
                                            .background(
                                                Circle()
                                                    .stroke(playerService.isShuffleEnabled ? Color.blue : Color.primary.opacity(0.25), lineWidth: 1.2)
                                            )
                                    }
                                    
                                    Spacer()
                                    
                                    // Prev
                                    Button(action: { playerService.previousTrack() }) {
                                        Image(systemName: "backward.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                            .frame(width: 38, height: 38)
                                            .background(
                                                Circle()
                                                    .stroke(Color.primary.opacity(0.25), lineWidth: 1.2)
                                            )
                                    }
                                    
                                    Spacer()
                                    
                                    // Play/Pause
                                    Button(action: { playerService.togglePlayPause() }) {
                                        Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.blue)
                                            .frame(width: 46, height: 46)
                                            .background(
                                                Circle()
                                                    .stroke(Color.blue, lineWidth: 1.5)
                                            )
                                    }
                                    
                                    Spacer()
                                    
                                    // Next
                                    Button(action: { playerService.nextTrack() }) {
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                            .frame(width: 38, height: 38)
                                            .background(
                                                Circle()
                                                    .stroke(Color.primary.opacity(0.25), lineWidth: 1.2)
                                            )
                                    }
                                    
                                    Spacer()
                                    
                                    // Repeat
                                    Button(action: { playerService.toggleRepeat() }) {
                                        Image(systemName: playerService.isRepeatEnabled ? "repeat.1" : "repeat")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(playerService.isRepeatEnabled ? .blue : .primary)
                                            .frame(width: 32, height: 32)
                                            .background(
                                                Circle()
                                                    .stroke(playerService.isRepeatEnabled ? Color.blue : Color.primary.opacity(0.25), lineWidth: 1.2)
                                            )
                                    }
                                }
                                .foregroundColor(.primary)
                                
                                // Volume Control
                                HStack(alignment: .center, spacing: 10) {
                                    Image(systemName: "speaker.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    
                                    VolumeSlider()
                                        .frame(height: 22)
                                    
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer(minLength: 4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.leading, 44) // Extra padding to clear the top-left dismiss button
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                } else {
                    // Portrait Layout
                    // Deduct 340 (since geometry.size respects safe area now, we need less subtracted budget than full screen height)
                    let portraitArtworkSize = max(120.0, min(300.0, min(geometry.size.width - 64.0, geometry.size.height - 340.0)))
                    
                    VStack {
                        // Dismiss chevron bar
                        HStack {
                            Button(action: {
                                withAnimation {
                                    isPresented = false
                                }
                            }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(10)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 16)
                            
                            Spacer()
                        }
                        .padding(.top, isSmallScreen ? 4 : 8)
                        
                        Spacer(minLength: isSmallScreen ? 2 : 4)
                        
                        // Big Artwork Vinyl
                        if let track = playerService.currentTrack {
                            if let url = track.fullArtworkUrl {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                         .aspectRatio(contentMode: .fit)
                                         .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                } placeholder: {
                                    ProgressView()
                                         .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                }
                                .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                .cornerRadius(20)
                                .shadow(radius: 15)
                                .rotationEffect(Angle(degrees: playerService.isPlaying ? 360 : 0))
                                .animation(playerService.isPlaying ? Animation.linear(duration: 25).repeatForever(autoreverses: false) : .default, value: playerService.isPlaying)
                                .gesture(
                                    DragGesture()
                                        .onEnded { value in
                                            if value.translation.height > 80 {
                                                withAnimation {
                                                    isPresented = false
                                                }
                                            }
                                        }
                                )
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: portraitArtworkSize * 0.27))
                                    .foregroundColor(.secondary)
                                    .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(20)
                                    .shadow(radius: 10)
                                    .gesture(
                                        DragGesture()
                                            .onEnded { value in
                                                if value.translation.height > 80 {
                                                    withAnimation {
                                                        isPresented = false
                                                    }
                                                }
                                            }
                                    )
                            }
                            
                            VStack(spacing: 4) {
                                Text(track.displayName)
                                    .font(isSmallScreen ? .headline : .title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Text(track.displayArtist)
                                    .font(isSmallScreen ? .subheadline : .headline)
                                    .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                            }
                            .padding(.top, isSmallScreen ? 8 : 16)
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
                                        if value.translation.height > 80 {
                                            withAnimation {
                                                isPresented = false
                                            }
                                        }
                                    }
                            )
                        }
                        
                        // Gap above the Progress Bar
                        Spacer(minLength: isSmallScreen ? 8 : 16)
                        
                        // Progress Slider
                        VStack(spacing: isSmallScreen ? 4 : 8) {
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
                        .padding(.horizontal, 12)
                        
                        // Gap between Progress Bar and Player Controls
                        Spacer(minLength: isSmallScreen ? 8 : 16)
                        
                        // Player Controls
                        HStack(spacing: isSmallScreen ? 16 : 24) {
                            // Shuffle
                            Button(action: { playerService.toggleShuffle() }) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: isSmallScreen ? 12 : 14, weight: .bold))
                                    .foregroundColor(playerService.isShuffleEnabled ? .blue : .primary)
                                    .frame(width: isSmallScreen ? 34 : 40, height: isSmallScreen ? 34 : 40)
                                    .background(
                                        Circle()
                                            .stroke(playerService.isShuffleEnabled ? Color.blue : Color.primary.opacity(0.25), lineWidth: 1.2)
                                    )
                            }
                            
                            // Prev
                            Button(action: { playerService.previousTrack() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: isSmallScreen ? 16 : 20))
                                    .foregroundColor(.primary)
                                    .frame(width: isSmallScreen ? 40 : 50, height: isSmallScreen ? 40 : 50)
                                    .background(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.25), lineWidth: 1.2)
                                    )
                            }
                            
                            // Play/Pause
                            Button(action: { playerService.togglePlayPause() }) {
                                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: isSmallScreen ? 20 : 24))
                                    .foregroundColor(.blue)
                                    .frame(width: isSmallScreen ? 54 : 64, height: isSmallScreen ? 54 : 64)
                                    .background(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 1.5)
                                    )
                            }
                            
                            // Next
                            Button(action: { playerService.nextTrack() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: isSmallScreen ? 16 : 20))
                                    .foregroundColor(.primary)
                                    .frame(width: isSmallScreen ? 40 : 50, height: isSmallScreen ? 40 : 50)
                                    .background(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.25), lineWidth: 1.2)
                                    )
                            }
                            
                            // Repeat
                            Button(action: { playerService.toggleRepeat() }) {
                                Image(systemName: playerService.isRepeatEnabled ? "repeat.1" : "repeat")
                                    .font(.system(size: isSmallScreen ? 12 : 14, weight: .bold))
                                    .foregroundColor(playerService.isRepeatEnabled ? .blue : .primary)
                                    .frame(width: isSmallScreen ? 34 : 40, height: isSmallScreen ? 34 : 40)
                                    .background(
                                        Circle()
                                            .stroke(playerService.isRepeatEnabled ? Color.blue : Color.primary.opacity(0.25), lineWidth: 1.2)
                                    )
                            }
                        }
                        .foregroundColor(.primary)
                        
                        // Gap between Player Controls and Volume Control
                        Spacer(minLength: isSmallScreen ? 12 : 28)
                        
                        // Volume Control
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                            
                            VolumeSlider()
                                .frame(height: 22)
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, isSmallScreen ? 8 : 16)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
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

struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        return volumeView
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
