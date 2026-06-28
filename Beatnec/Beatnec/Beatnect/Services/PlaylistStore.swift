import Foundation
import SwiftUI
import Combine

class PlaylistStore: ObservableObject {
    static let shared = PlaylistStore()

    @Published var playlists: [Playlist] = [] {
        didSet { save() }
    }

    private let key = "beatnect_playlists"

    private init() {
        load()
    }

    // MARK: - CRUD

    func createPlaylist(name: String) {
        playlists.append(Playlist(name: name))
    }

    func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
    }

    func renamePlaylist(_ playlist: Playlist, to name: String) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[i].name = name
    }

    func addTrack(_ track: Track, to playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        let compositeKey = "\(track.displayName)||\(track.displayArtist)"
        if !playlists[i].trackIDs.contains(track.id) {
            playlists[i].trackIDs.append(track.id)
        }
        if !playlists[i].trackIDs.contains(compositeKey) {
            playlists[i].trackIDs.append(compositeKey)
        }
    }

    func removeTrack(id: String, from playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        // Find track in allTracks to compute composite key if needed
        let compositeKey: String? = AudioPlayerService.shared.libraryTracks.first { $0.id == id }.map { "\($0.displayName)||\($0.displayArtist)" }
        playlists[i].trackIDs.removeAll { $0 == id || (compositeKey != nil && $0 == compositeKey) }
    }

    func tracks(for playlist: Playlist, allTracks: [Track]) -> [Track] {
        var matchedTracks = [Track]()
        var seenIDs = Set<String>()
        
        for key in playlist.trackIDs {
            if let track = allTracks.first(where: { $0.id == key || "\($0.displayName)||\($0.displayArtist)" == key }) {
                if !seenIDs.contains(track.id) {
                    matchedTracks.append(track)
                    seenIDs.insert(track.id)
                }
            }
        }
        return matchedTracks
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else { return }
        playlists = decoded
    }
}
