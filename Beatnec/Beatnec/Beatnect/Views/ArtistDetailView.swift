import SwiftUI

struct ArtistDetailView: View {
    let artist: String
    let tracks: [Track]
    @StateObject private var playerService = AudioPlayerService.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        // Artist Icon Placeholder
                        ZStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                                .frame(width: 180, height: 180)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                        }
                        
                        // Metadata
                        VStack(spacing: 6) {
                            Text(artist)
                                .font(.system(.title2))
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.primaryTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            Text("\(tracks.count) Songs")
                                .font(.system(.caption))
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        // Play Artist Button
                        Button(action: {
                            if !tracks.isEmpty {
                                playerService.setPlaylist(tracks: tracks, startAtIndex: 0)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Play Artist")
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
                        .disabled(tracks.isEmpty)
                    }
                    .padding(.top, 24)
                    
                    // Tracks List
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            let isCurrent = playerService.currentTrack?.id == track.id
                            
                            Button(action: {
                                playerService.setPlaylist(tracks: tracks, startAtIndex: index)
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
                                    
                                    // Title & Album
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.displayName)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(isCurrent ? .blue : themeManager.primaryTextColor)
                                            .lineLimit(1)
                                        
                                        Text(track.displayAlbum)
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
