import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @StateObject private var playerService = AudioPlayerService.shared
    
    var body: some View {
        ZStack {
            // Premium Charcoal Black Background with very subtle blurred artwork overlay
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.09) // Sleek Charcoal Black
                
                if let url = album.artworkUrl {
                    AsyncImage(url: url) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.clear
                    }
                    .blur(radius: 60)
                    .opacity(0.12) // Very subtle blurred artwork overlay for premium depth
                }
            }
            .ignoresSafeArea()
            
            // Content Scroll
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        // Album Art Cover with Colored Shadow
                        ZStack {
                            if let url = album.artworkUrl {
                                // shadow copy
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                         .aspectRatio(contentMode: .fit)
                                         .frame(width: 180, height: 180)
                                } placeholder: {
                                    Color.clear
                                        .frame(width: 180, height: 180)
                                }
                                .frame(width: 180, height: 180)
                                .blur(radius: 20)
                                .opacity(0.6)
                                .offset(y: 10)
                                
                                // main art
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                         .aspectRatio(contentMode: .fit)
                                         .frame(width: 180, height: 180)
                                } placeholder: {
                                    ProgressView()
                                         .frame(width: 180, height: 180)
                                }
                                .frame(width: 180, height: 180)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                                )
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 64))
                                    .foregroundColor(.secondary)
                                    .frame(width: 180, height: 180)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(16)
                                    .shadow(radius: 8)
                            }
                        }
                        
                        // Metadata
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
                                .foregroundColor(.secondary)
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
                            .padding(.vertical, 12)
                            .padding(.horizontal, 32)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(red: 0.65, green: 0.8, blue: 0.22))
                            )
                            .foregroundColor(.black)
                            .shadow(color: Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.35), radius: 8, x: 0, y: 4)
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
                                    // Index
                                    Text("\(index + 1)")
                                        .font(.system(.body))
                                        .foregroundColor(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .secondary)
                                        .frame(width: 28, alignment: .trailing)
                                    
                                    // Title & Artist
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.displayName)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .primary)
                                            .lineLimit(1)
                                        
                                        Text(track.displayArtist)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                    
                                    // Playing Indicator
                                    if isCurrent {
                                        Image(systemName: playerService.isPlaying ? "waveform.and.mic" : "play.fill")
                                            .foregroundColor(Color(red: 0.65, green: 0.8, blue: 0.22))
                                            .font(.system(size: 14))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isCurrent ? Color.white.opacity(0.06) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.3) : Color.clear, lineWidth: 1.0)
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
        .preferredColorScheme(.dark)
    }
}
