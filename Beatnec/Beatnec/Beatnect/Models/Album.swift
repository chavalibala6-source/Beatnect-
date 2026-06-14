import Foundation

struct Album: Identifiable, Equatable {
    var id: String {
        return name + "|" + artist
    }
    let name: String
    let artist: String
    let artworkUrl: URL?
    var tracks: [Track]
}
