import SwiftUI

struct PlaylistPickerView: View {
    let track: Track?
    let onDismiss: () -> Void
    let onNewPlaylist: () -> Void
    @ObservedObject var playlistStore = PlaylistStore.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // New Playlist Button
                    Button(action: onNewPlaylist) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            Text("New Playlist...")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .padding(.all, 16)
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if playlistStore.playlists.isEmpty {
                                Text("No playlists yet")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 40)
                            } else {
                                ForEach(playlistStore.playlists) { playlist in
                                    Button(action: {
                                        if let track = track {
                                            playlistStore.addTrack(track, to: playlist)
                                        }
                                        onDismiss()
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: "music.note.list")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                                .frame(width: 44, height: 44)
                                                .background(Color.white.opacity(0.12))
                                                .cornerRadius(8)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(playlist.name)
                                                    .font(.headline)
                                                    .foregroundColor(themeManager.primaryTextColor)
                                                Text("\(playlistStore.tracks(for: playlist, allTracks: AudioPlayerService.shared.libraryTracks).count) songs")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 24)
                                    }
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 84)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel", action: onDismiss).foregroundColor(.white))
        }
    }
}
