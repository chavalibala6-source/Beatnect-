import Foundation

struct Track: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var artist: String?
    var album: String?
    
    var displayArtist: String { artist ?? "Unknown Artist" }
    var displayAlbum: String { album ?? "Unknown Album" }
}

var libraryTracks: [Track] = [
    Track(id: "1", name: "A1", artist: "Art", album: "Album1"),
    Track(id: "2", name: "A2", artist: "Art", album: "Album1"),
    Track(id: "3", name: "B1", artist: "Art2", album: "Album2")
]

var tracks: [Track] = [
    Track(id: "1", name: "A1", artist: "Art", album: "Album1"),
    Track(id: "2", name: "A2", artist: "Art", album: "Album1")
]

var currentTrackIndex: Int? = 1
var isAutoPlayEnabled = true
var isShuffleEnabled = false

var currentTrack: Track? { tracks[currentTrackIndex!] }

func setPlaylist(tracks: [Track], startAtIndex: Int) {
    print("setPlaylist called with \(tracks.count) tracks")
}

func stopCurrentPlayback() {
    print("stopCurrentPlayback called")
}

func playTrack(at next: Int) {
    print("playTrack called with index \(next)")
}

let currentIndex = currentTrackIndex ?? 0
if !isShuffleEnabled && currentIndex == tracks.count - 1 {
    if isAutoPlayEnabled, let track = currentTrack, let libIndex = libraryTracks.firstIndex(where: { $0.id == track.id }) {
        var nextAlbumTrack: Track? = nil
        for i in (libIndex + 1)..<libraryTracks.count {
            let candidate = libraryTracks[i]
            if candidate.displayAlbum != track.displayAlbum || candidate.displayArtist != track.displayArtist {
                nextAlbumTrack = candidate
                break
            }
        }
        
        if nextAlbumTrack == nil {
            for i in 0..<libIndex {
                let candidate = libraryTracks[i]
                if candidate.displayAlbum != track.displayAlbum || candidate.displayArtist != track.displayArtist {
                    nextAlbumTrack = candidate
                    break
                }
            }
        }
        
        if let nextTrack = nextAlbumTrack {
            let nextAlbumTracks = libraryTracks.filter { $0.displayAlbum == nextTrack.displayAlbum && $0.displayArtist == nextTrack.displayArtist }
            if !nextAlbumTracks.isEmpty {
                setPlaylist(tracks: nextAlbumTracks, startAtIndex: 0)
                exit(0)
            }
        }
    }
    
    stopCurrentPlayback()
    exit(0)
}

playTrack(at: 0)
