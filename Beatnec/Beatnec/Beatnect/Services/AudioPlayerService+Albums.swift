import Foundation

extension AudioPlayerService {
    var recentlyAddedAlbums: [Album] {
        Array(precomputedAlbums.suffix(6).reversed())
    }
    
    var artistGroupedAlbums: [(artist: String, albums: [Album])] {
        var dict = [String: [Album]]()
        for album in precomputedAlbums {
            let artist = album.artist.isEmpty ? "Unknown Artist" : album.artist
            dict[artist, default: []].append(album)
        }
        return dict.map { (artist: $0.key, albums: $0.value.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })) }
            .sorted(by: { $0.artist.lowercased() < $1.artist.lowercased() })
    }
}
