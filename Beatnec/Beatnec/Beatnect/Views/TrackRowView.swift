import SwiftUI

struct TrackRowView: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork Image
            if let url = track.fullArtworkUrl {
                AsyncImage(url: url) { image in
                    image.resizable()
                         .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 44, height: 44)
                .cornerRadius(6)
                .clipped()
            } else {
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(6)
            }
            
            // Text Meta
            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(isCurrent ? .blue : .primary)
                    .lineLimit(1)
                
                Text(track.displayArtist)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Visualizer / Playing State Icon
            if isCurrent {
                if isPlaying {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            Capsule()
                                .fill(Color.blue)
                                .frame(width: 3, height: 12)
                                .scaleEffect(y: isPlaying ? CGFloat.random(in: 0.4...1.2) : 0.4, anchor: .center)
                                .animation(Animation.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.1), value: isPlaying)
                        }
                    }
                } else {
                    Image(systemName: "speaker.wave.1.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
