import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @StateObject private var playerService = AudioPlayerService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var playlistStore = PlaylistStore.shared
    
    var body: some View {
        let playlistTracks = playlistStore.tracks(for: playlist, allTracks: playerService.libraryTracks)
        
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        // Artwork Overlay
                        ZStack {
                            if let firstTrack = playlistTracks.first, let url = firstTrack.fullArtworkUrl {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable()
                                         .aspectRatio(contentMode: .fit)
                                         .frame(width: 220, height: 220)
                                } placeholder: {
                                    Image("music_thumb")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 220, height: 220)
                                }
                                .frame(width: 220, height: 220)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                            } else {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 64))
                                    .foregroundColor(.secondary)
                                    .frame(width: 220, height: 220)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                            }
                        }
                        
                        // Metadata
                        VStack(spacing: 6) {
                            Text(playlist.name)
                                .font(.system(.title2))
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.primaryTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            Text("\(playlistTracks.count) Songs")
                                .font(.system(.caption))
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        // Play Playlist Button
                        Button(action: {
                            if !playlistTracks.isEmpty {
                                playerService.setPlaylist(tracks: playlistTracks, startAtIndex: 0)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Play Playlist")
                                    .fontWeight(.bold)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 40)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(themeManager.isDarkMode ? Color.white : Color.black)
                            )
                            .foregroundColor(themeManager.isDarkMode ? .black : .white)
                        }
                        .padding(.top, 4)
                        .disabled(playlistTracks.isEmpty)
                    }
                    .padding(.top, 24)
                    
                    // Tracks List
                    LazyVStack(spacing: 0) {
                        if playlistTracks.isEmpty {
                            Text("No songs in this playlist yet")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        } else {
                            ForEach(Array(playlistTracks.enumerated()), id: \.element.id) { index, track in
                                let isCurrent = playerService.currentTrack?.id == track.id
                                
                                Button(action: {
                                    playerService.setPlaylist(tracks: playlistTracks, startAtIndex: index)
                                }) {
                                    HStack(spacing: 16) {
                                        // Index or Playing Indicator
                                        if isCurrent {
                                            Image(systemName: "waveform")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14))
                                                .frame(width: 28, alignment: .trailing)
                                        } else {
                                            Color.clear
                                                .frame(width: 28)
                                        }
                                        
                                        // Title & Artist
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.displayName)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(isCurrent ? .blue : themeManager.primaryTextColor)
                                                .lineLimit(1)
                                            
                                            Text(track.displayArtist)
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(isCurrent ? Color(UIColor.secondarySystemBackground) : Color.clear)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.bottom, 80) // Space for MiniPlayerBar
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
