import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    var tabBarTemplate: CPTabBarTemplate?
    var libraryTemplate: CPListTemplate?
    var nowPlayingObserver: NSObjectProtocol?

    // MARK: - Connect

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        // Build tab bar with icons
        let tabs = buildTabBarTemplate()
        self.tabBarTemplate = tabs
        interfaceController.setRootTemplate(tabs, animated: true, completion: nil)

        // Load tracks into Library tab
        loadTracks()

        // Observe track changes to refresh now-playing badge
        nowPlayingObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TrackDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshNowPlayingButton()
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        if let observer = nowPlayingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        self.interfaceController = nil
        self.tabBarTemplate = nil
        self.libraryTemplate = nil
    }

    // MARK: - Tab Bar

    private func buildTabBarTemplate() -> CPTabBarTemplate {
        // ── Library Tab ────────────────────────────────────────────────────
        let library = CPListTemplate(title: "Library", sections: [])
        library.tabTitle = "Library"
        library.tabImage = UIImage(systemName: "music.note.list",
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))

        // ── Now Playing Tab ────────────────────────────────────────────────
        let nowPlaying = CPNowPlayingTemplate.shared
        // CPNowPlayingTemplate is a singleton — access via .shared

        // ── Browse Tab (Artists) ────────────────────────────────────────────
        let browse = CPListTemplate(title: "Artists", sections: [])
        browse.tabTitle = "Artists"
        browse.tabImage = UIImage(systemName: "person.2.fill",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))

        self.libraryTemplate = library

        return CPTabBarTemplate(templates: [library, nowPlaying, browse])
    }

    // MARK: - Load Tracks

    func loadTracks() {
        APIService.shared.fetchTracks { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tracks):
                    self?.buildLibraryTemplate(with: tracks)
                    self?.buildArtistTemplate(with: tracks)
                case .failure(let error):
                    print("CarPlay: failed to fetch tracks — \(error)")
                    self?.showErrorTemplate(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Library List

    private func buildLibraryTemplate(with tracks: [Track]) {
        guard let libraryTemplate = libraryTemplate else { return }

        // Header item — shows current playback state
        let currentTrackName = AudioPlayerService.shared.currentTrack?.displayName ?? "Nothing playing"
        let nowPlayingItem = CPListItem(
            text: "▶︎  Now Playing",
            detailText: currentTrackName
        )
        nowPlayingItem.setImage(
            UIImage(systemName: "waveform",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        )
        nowPlayingItem.handler = { [weak self] _, completion in
            if let nowPlaying = self?.tabBarTemplate?.templates.first(where: { $0 is CPNowPlayingTemplate }) {
                self?.interfaceController?.pushTemplate(nowPlaying, animated: true, completion: nil)
            }
            completion()
        }

        let headerSection = CPListSection(
            items: [nowPlayingItem],
            header: nil,
            headerSubtitle: nil,
            headerImage: UIImage(systemName: "beats.headphones"),
            headerButton: nil,
            sectionIndexTitle: nil
        )

        // Track items
        var trackItems = [CPListItem]()
        for (index, track) in tracks.enumerated() {
            let isCurrentlyPlaying = AudioPlayerService.shared.currentTrack?.id == track.id
                                  && AudioPlayerService.shared.isPlaying

            let item = CPListItem(
                text: track.displayName,
                detailText: track.displayArtist
            )

            // Playback indicator icon
            let iconName = isCurrentlyPlaying ? "speaker.wave.2.fill" : "music.note"
            item.setImage(
                UIImage(systemName: iconName,
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular))
            )

            item.handler = { _, completion in
                AudioPlayerService.shared.setPlaylist(tracks: tracks, startAtIndex: index)
                completion()
            }

            // Load artwork asynchronously and replace icon
            if let url = track.fullArtworkUrl {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        let resized = image.resized(to: CGSize(width: 44, height: 44))
                        DispatchQueue.main.async {
                            item.setImage(resized)
                        }
                    }
                }.resume()
            }

            trackItems.append(item)
        }

        let tracksSection = CPListSection(
            items: trackItems,
            header: "All Songs",
            headerSubtitle: "\(tracks.count) tracks",
            headerImage: UIImage(systemName: "music.note",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)),
            headerButton: nil,
            sectionIndexTitle: "♫"
        )

        libraryTemplate.updateSections([headerSection, tracksSection])
    }

    // MARK: - Artist List

    private func buildArtistTemplate(with tracks: [Track]) {
        guard let browseTemplate = tabBarTemplate?.templates.last as? CPListTemplate else { return }

        let grouped = Dictionary(grouping: tracks) { $0.displayArtist }
        let sorted = grouped.keys.sorted()

        var artistItems = [CPListItem]()
        for artist in sorted {
            let artistTracks = grouped[artist] ?? []
            let item = CPListItem(
                text: artist,
                detailText: "\(artistTracks.count) songs"
            )
            item.setImage(
                UIImage(systemName: "person.fill",
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
            )
            item.handler = { _, completion in
                AudioPlayerService.shared.setPlaylist(tracks: artistTracks, startAtIndex: 0)
                completion()
            }
            artistItems.append(item)
        }

        let section = CPListSection(
            items: artistItems,
            header: "Artists",
            headerSubtitle: "\(sorted.count) artists",
            headerImage: UIImage(systemName: "person.2.fill",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)),
            headerButton: nil,
            sectionIndexTitle: nil
        )
        browseTemplate.updateSections([section])
    }

    // MARK: - Now Playing Refresh

    private func refreshNowPlayingButton() {
        // Reload library list to update the "Now Playing" banner item
        APIService.shared.fetchTracks { [weak self] result in
            if case .success(let tracks) = result {
                DispatchQueue.main.async {
                    self?.buildLibraryTemplate(with: tracks)
                }
            }
        }
    }

    // MARK: - Error

    private func showErrorTemplate(message: String) {
        let errorItem = CPListItem(
            text: "Unable to load library",
            detailText: message
        )
        errorItem.setImage(
            UIImage(systemName: "exclamationmark.triangle.fill",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 16))
        )
        let section = CPListSection(items: [errorItem])
        libraryTemplate?.updateSections([section])
    }
}

// MARK: - UIImage resize helper

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
