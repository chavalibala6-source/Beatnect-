import SwiftUI
import PlaygroundSupport

struct ContentView: View {
    @State private var items = ["A", "B", "C"]
    @State private var editMode: EditMode = .active
    
    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .listRowBackground(Color.clear)
            }
            .onMove { source, dest in
                items.move(fromOffsets: source, toOffset: dest)
            }
        }
        .environment(\.editMode, $editMode)
    }
}
