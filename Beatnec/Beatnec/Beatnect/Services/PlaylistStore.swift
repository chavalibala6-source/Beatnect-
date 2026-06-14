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
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }),
              !playlists[i].trackIDs.contains(track.id) else { return }
        playlists[i].trackIDs.append(track.id)
    }

    func removeTrack(id: String, from playlist: Playlist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[i].trackIDs.removeAll { $0 == id }
    }

    func tracks(for playlist: Playlist, allTracks: [Track]) -> [Track] {
        playlist.trackIDs.compactMap { id in allTracks.first { $0.id == id } }
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
