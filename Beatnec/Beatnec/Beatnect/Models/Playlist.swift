import Foundation

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var trackIDs: [String]   // Track.id values

    init(id: UUID = UUID(), name: String, trackIDs: [String] = []) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
    }
}
