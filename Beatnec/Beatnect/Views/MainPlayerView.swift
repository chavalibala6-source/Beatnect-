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
                .cornerRadius(10)
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                )
            } else {
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
                    .frame(width: 48, height: 48)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
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
            }
            .buttonStyle(LiquidGlassButtonStyle(isActive: isPlaying, activeColor: .blue, size: 38))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Rectangle()
                    .fill(.thinMaterial)
                Color.black.opacity(0.02)
            }
        )
        .overlay(
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.2), .clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                Spacer()
            }
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: -4)
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
        GeometryReader { geometry in
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
                                            AsyncImage(url: url) { image in
                                                image.resizable()
                                                     .aspectRatio(contentMode: .fit)
                                            } placeholder: {
                                                Color.clear
                                            }
                                            .frame(maxHeight: landscapeArtworkSize)
                                            .rotationEffect(Angle(degrees: playerService.isPlaying ? 360 : 0))
                                            .animation(playerService.isPlaying ? Animation.linear(duration: 25).repeatForever(autoreverses: false) : .default, value: playerService.isPlaying)
                                            .blur(radius: 20)
                                            .opacity(0.6)
                                            .offset(y: 10)
                                            
                                            // Main Artwork image
                                            AsyncImage(url: url) { image in
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
                                        Text(track.displayName)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .lineLimit(1)
                                        
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
                                
                                Spacer(minLength: 14)
                                
                                // Playback Controls (Row 1)
                                HStack(spacing: 20) {
                                    Spacer()
                                    // Prev
                                    Button(action: { playerService.previousTrack() }) {
                                        Image(systemName: "backward.fill")
                                    }
                                    .buttonStyle(LiquidGlassButtonStyle(isActive: false, size: 38))
                                    
                                    // Play/Pause
                                    Button(action: { playerService.togglePlayPause() }) {
                                        Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                    }
                                    .buttonStyle(LiquidGlassButtonStyle(isActive: playerService.isPlaying, activeColor: .blue, size: 46))
                                    
                                    // Next
                                    Button(action: { playerService.nextTrack() }) {
                                        Image(systemName: "forward.fill")
                                    }
                                    .buttonStyle(LiquidGlassButtonStyle(isActive: false, size: 38))
                                    Spacer()
                                }
                                
                                Spacer(minLength: 12)
                                
                                // Shuffle & Repeat Controls (Row 2)
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
                                
                                Spacer(minLength: 20)
                                
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
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                             .aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        Color.clear
                                    }
                                    .frame(width: portraitArtworkSize, height: portraitArtworkSize)
                                    .rotationEffect(Angle(degrees: playerService.isPlaying ? 360 : 0))
                                    .animation(playerService.isPlaying ? Animation.linear(duration: 25).repeatForever(autoreverses: false) : .default, value: playerService.isPlaying)
                                    .blur(radius: 24)
                                    .opacity(0.65)
                                    .offset(y: 12)
                                    
                                    // Main Artwork image
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
                                    .rotationEffect(Angle(degrees: playerService.isPlaying ? 360 : 0))
                                    .animation(playerService.isPlaying ? Animation.linear(duration: 25).repeatForever(autoreverses: false) : .default, value: playerService.isPlaying)
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
                                    Text(track.displayName)
                                        .font(isSmallScreen ? .headline : .title2)
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
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
                            .padding(.horizontal, 16)
                            
                            Spacer()
                            
                            // Playback Controls (Row 1)
                            HStack(spacing: isSmallScreen ? 24 : 36) {
                                Spacer()
                                // Prev
                                Button(action: { playerService.previousTrack() }) {
                                    Image(systemName: "backward.fill")
                                }
                                .buttonStyle(LiquidGlassButtonStyle(isActive: false, size: isSmallScreen ? 44 : 54))
                                
                                // Play/Pause
                                Button(action: { playerService.togglePlayPause() }) {
                                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                }
                                .buttonStyle(LiquidGlassButtonStyle(isActive: playerService.isPlaying, activeColor: .blue, size: isSmallScreen ? 60 : 72))
                                
                                // Next
                                Button(action: { playerService.nextTrack() }) {
                                    Image(systemName: "forward.fill")
                                }
                                .buttonStyle(LiquidGlassButtonStyle(isActive: false, size: isSmallScreen ? 44 : 54))
                                Spacer()
                            }
                            
                            Spacer()
                            
                            // Shuffle & Repeat Controls (Row 2)
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
                            
                            Spacer()
                            
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
                            .padding(.horizontal, 4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, isSmallScreen ? 8 : 16)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
        .background(
            ZStack {
                if let track = playerService.currentTrack, let url = track.fullArtworkUrl {
                    AsyncImage(url: url) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.clear
                    }
                    .blur(radius: 40)
                    .opacity(0.4)
                } else {
                    Color.clear
                }
            }
            .ignoresSafeArea()
        )
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
        
        // Custom styling for the volume slider to match liquid glass look
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                slider.minimumTrackTintColor = UIColor(red: 0.65, green: 0.8, blue: 0.22, alpha: 0.85) // Glowing lime
                slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.15) // Glass track
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
