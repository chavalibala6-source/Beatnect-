import SwiftUI

struct TestView: View {
    @State private var items = ["Track 1", "Track 2", "Track 3"]
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
