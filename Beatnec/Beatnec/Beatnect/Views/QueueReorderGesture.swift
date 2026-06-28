import SwiftUI

struct QueueReorderGesture: ViewModifier {
    let track: Track
    @ObservedObject var playerService: AudioPlayerService
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var originalIndex: Int? = nil
    
    let rowHeight: CGFloat = 64
    
    func body(content: Content) -> some View {
        content
            .offset(y: isDragging ? dragOffset : 0)
            .zIndex(isDragging ? 100 : 0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            originalIndex = playerService.tracks.firstIndex(of: track)
                        }
                        
                        dragOffset = value.translation.height
                        
                        guard let currentIndex = playerService.tracks.firstIndex(of: track) else { return }
                        
                        let offsetIndex = Int(round(dragOffset / rowHeight))
                        
                        if offsetIndex != 0 {
                            let nextIndex = (playerService.currentTrackIndex ?? -1) + 1
                            let newIndex = max(nextIndex, min(playerService.tracks.count - 1, currentIndex + offsetIndex))
                            
                            if newIndex != currentIndex {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    playerService.tracks.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: newIndex > currentIndex ? newIndex + 1 : newIndex)
                                    // Adjust drag offset so the visual position remains smooth
                                    dragOffset -= CGFloat(newIndex - currentIndex) * rowHeight
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                            isDragging = false
                            originalIndex = nil
                        }
                    }
            )
    }
}

extension View {
    func instantQueueReorder(track: Track, playerService: AudioPlayerService) -> some View {
        self.modifier(QueueReorderGesture(track: track, playerService: playerService))
    }
}
