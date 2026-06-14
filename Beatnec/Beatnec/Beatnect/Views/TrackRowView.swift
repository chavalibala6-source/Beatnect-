import SwiftUI

struct TrackRowView: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Artwork Image
            if let url = track.fullArtworkUrl {
                AsyncImage(url: url) { image in
                    image.resizable()
                         .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 54, height: 54)
                .cornerRadius(10)
                .clipped()
            } else {
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
                    .frame(width: 54, height: 54)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            
            // Text Meta
            VStack(alignment: .leading, spacing: 4) {
                Text(track.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isCurrent ? .blue : .black)
                    .lineLimit(1)
                
                Text(track.displayArtist)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.16))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Visualizer / Playing State Icon
            if isCurrent {
                if isPlaying {
                    HStack(spacing: 2.5) {
                        ForEach(0..<3) { i in
                            Capsule()
                                .fill(Color.blue)
                                .frame(width: 3, height: 14)
                                .scaleEffect(y: isPlaying ? CGFloat.random(in: 0.4...1.2) : 0.4, anchor: .center)
                                .animation(Animation.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.1), value: isPlaying)
                        }
                    }
                } else {
                    Image(systemName: "speaker.wave.1.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrent ? Color(.secondarySystemBackground) : Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrent ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
