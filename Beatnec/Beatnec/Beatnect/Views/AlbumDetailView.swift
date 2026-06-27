import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @StateObject private var playerService = AudioPlayerService.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()
            
            // Content Scroll
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        // Album Art Cover
                        ZStack {
                            if let url = album.artworkUrl {
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
                                Image("music_thumb")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 220, height: 220)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                            }
                        }
                        
                        // Metadata
                        VStack(spacing: 6) {
                            Text(album.name)
                                .font(.system(.title2))
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.primaryTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            Text(album.artist)
                                .font(.system(.headline))
                                .foregroundColor(.secondary)
                            
                            Text("\(album.tracks.count) Songs")
                                .font(.system(.caption))
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        // Play Album Button
                        Button(action: {
                            if !album.tracks.isEmpty {
                                playerService.setPlaylist(tracks: album.tracks, startAtIndex: 0)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Play Album")
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
                    }
                    .padding(.top, 24)
                    
                    // Tracks List
                    LazyVStack(spacing: 0) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                            let isCurrent = playerService.currentTrack?.id == track.id
                            
                            Button(action: {
                                playerService.setPlaylist(tracks: album.tracks, startAtIndex: index)
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
                    .padding(.bottom, 80) // Space for MiniPlayerBar
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

