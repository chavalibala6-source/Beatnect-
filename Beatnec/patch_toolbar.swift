struct PlayerToolbar: View {
    @ObservedObject var playerService: AudioPlayerService
    var isSmallScreen: Bool
    
    var body: some View {
        HStack(spacing: 30) {
            Button {
                playerService.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: isSmallScreen ? 28 : 36))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                playerService.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: isSmallScreen ? 64 : 80, height: isSmallScreen ? 64 : 80)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: isSmallScreen ? 64 : 80, height: isSmallScreen ? 64 : 80)
                    
                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isSmallScreen ? 28 : 36))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                playerService.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: isSmallScreen ? 28 : 36))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
    }
}
