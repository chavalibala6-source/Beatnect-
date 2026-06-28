import SwiftUI

struct QueueReorderModifier: ViewModifier {
    let itemIndex: Int
    let itemCount: Int
    let onMove: (Int, Int) -> Void // from, to
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: dragOffset)
            .zIndex(isDragging ? 1 : 0)
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        dragOffset = value.translation.height
                        
                        // row height is roughly 60
                        let rowHeight: CGFloat = 60
                        let offsetIndex = Int(round(dragOffset / rowHeight))
                        
                        if offsetIndex != 0 {
                            let newIndex = max(0, min(itemCount - 1, itemIndex + offsetIndex))
                            if newIndex != itemIndex {
                                onMove(itemIndex, newIndex)
                                // Adjust drag offset to prevent jumping since the item actually moved in the array
                                dragOffset -= CGFloat(offsetIndex) * rowHeight
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring()) {
                            dragOffset = 0
                            isDragging = false
                        }
                    }
            )
    }
}

extension View {
    func queueReorderable(index: Int, count: Int, onMove: @escaping (Int, Int) -> Void) -> some View {
        self.modifier(QueueReorderModifier(itemIndex: index, itemCount: count, onMove: onMove))
    }
}
