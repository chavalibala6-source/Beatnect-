import SwiftUI

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
                        List {
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
                        .listStyle(PlainListStyle())
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
            .sheet(isPresented: $isShowingPlayerDetail) {
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
            if let artworkUrlString = track.artworkUrl, let url = URL(string: artworkUrlString) {
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
    
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    
    var body: some View {
        ZStack {
            // Blurred Artwork Background
            if let track = playerService.currentTrack, let artworkUrlString = track.artworkUrl, let url = URL(string: artworkUrlString) {
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
            
            VStack {
                // Handle bar
                Capsule()
                    .fill(Color.secondary)
                    .frame(width: 40, height: 5)
                    .padding(.top, 16)
                
                Spacer()
                
                // Big Artwork Vinyl
                if let track = playerService.currentTrack {
                    if let artworkUrlString = track.artworkUrl, let url = URL(string: artworkUrlString) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                 .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 260, height: 260)
                        .cornerRadius(20)
                        .shadow(radius: 15)
                        .rotationEffect(Angle(degrees: playerService.isPlaying ? 360 : 0))
                        .animation(playerService.isPlaying ? Animation.linear(duration: 25).repeatForever(autoreverses: false) : .default, value: playerService.isPlaying)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                            .frame(width: 260, height: 260)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(20)
                            .shadow(radius: 10)
                    }
                    
                    VStack(spacing: 4) {
                        Text(track.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text(track.displayArtist)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)
                }
                
                Spacer()
                
                // Progress Slider
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
                    .accentColor(.blue)
                    
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
                .padding(.horizontal, 24)
                
                // Player Controls
                HStack(spacing: 48) {
                    // Prev
                    Button(action: { playerService.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 32))
                    }
                    
                    // Play/Pause
                    Button(action: { playerService.togglePlayPause() }) {
                        Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.blue)
                    }
                    
                    // Next
                    Button(action: { playerService.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 32))
                    }
                }
                .foregroundColor(.primary)
                .padding(.vertical, 24)
                
                Spacer()
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
