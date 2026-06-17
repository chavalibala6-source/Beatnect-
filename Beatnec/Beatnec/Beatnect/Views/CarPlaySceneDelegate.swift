import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    var libraryTemplate: CPListTemplate?
    var artistTemplate: CPListTemplate?

    // MARK: - Connect / Disconnect

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupRootTemplate(interfaceController)
        loadTracks()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.libraryTemplate = nil
        self.artistTemplate = nil
    }

    // MARK: - Root Template (Tab Bar with Icons)

    private func setupRootTemplate(_ interfaceController: CPInterfaceController) {
        // Library tab
        let libTemplate = CPListTemplate(title: "Library", sections: [])
        libTemplate.tabTitle = "Library"
        libTemplate.tabImage = icon("music.note.list")
        self.libraryTemplate = libTemplate

        // Now Playing tab (system-provided)
        let nowPlayingTemplate = CPNowPlayingTemplate.shared
        nowPlayingTemplate.tabTitle = "Now Playing"
        nowPlayingTemplate.tabImage = icon("play.circle.fill")

        // Artists tab
        let artTemplate = CPListTemplate(title: "Artists", sections: [])
        artTemplate.tabTitle = "Artists"
        artTemplate.tabImage = icon("person.2.fill")
        self.artistTemplate = artTemplate

        let tabBar = CPTabBarTemplate(templates: [libTemplate, nowPlayingTemplate, artTemplate])
        interfaceController.setRootTemplate(tabBar, animated: true, completion: nil)
    }

    // MARK: - Load Tracks

    private func loadTracks() {
        APIService.shared.fetchTracks { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tracks):
                    self?.populateLibrary(tracks: tracks)
                    self?.populateArtists(tracks: tracks)
                case .failure(let error):
                    self?.showError(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Library Tab

    private func populateLibrary(tracks: [Track]) {
        // Now-playing banner row
        let currentName = AudioPlayerService.shared.currentTrack?.displayName ?? "Nothing playing yet"
        let bannerItem = CPListItem(
            text: "Now Playing",
            detailText: currentName,
            image: icon("waveform", size: 28),
            accessoryImage: nil,
            accessoryType: .disclosureIndicator
        )
        bannerItem.handler = { [weak self] _, completion in
            if let vc = self?.interfaceController {
                vc.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
            completion()
        }
        let bannerSection = CPListSection(items: [bannerItem])

        // Track rows
        var trackItems: [CPListItem] = []
        for (index, track) in tracks.enumerated() {
            let isNowPlaying = AudioPlayerService.shared.currentTrack?.id == track.id
            let rowIcon = isNowPlaying ? icon("speaker.wave.2.fill", size: 28, tint: UIColor(red: 0.65, green: 0.8, blue: 0.22, alpha: 1))
                                       : icon("music.note", size: 28, tint: .secondaryLabel)

            let item = CPListItem(
                text: track.displayName,
                detailText: track.displayArtist,
                image: rowIcon,
                accessoryImage: nil,
                accessoryType: isNowPlaying ? .cloud : .none
            )

            // Tap → play
            item.handler = { _, completion in
                AudioPlayerService.shared.setPlaylist(tracks: tracks, startAtIndex: index)
                completion()
            }

            // Load album artwork and replace the SF symbol
            if let url = track.fullArtworkUrl {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data = data, let raw = UIImage(data: data) else { return }
                    let thumb = raw.roundedThumbnail(size: CGSize(width: 44, height: 44), cornerRadius: 6)
                    DispatchQueue.main.async {
                        item.setImage(thumb)
                    }
                }.resume()
            }

            trackItems.append(item)
        }

        let songsSection = CPListSection(
            items: trackItems,
            header: "All Songs — \(tracks.count) tracks",
            sectionIndexTitle: nil
        )

        libraryTemplate?.updateSections([bannerSection, songsSection])
    }

    // MARK: - Artists Tab

    private func populateArtists(tracks: [Track]) {
        let grouped = Dictionary(grouping: tracks) { $0.displayArtist }
        let sorted = grouped.keys.sorted()

        var items: [CPListItem] = []
        for artist in sorted {
            let artistTracks = grouped[artist] ?? []
            let item = CPListItem(
                text: artist,
                detailText: "\(artistTracks.count) song\(artistTracks.count == 1 ? "" : "s")",
                image: icon("person.fill", size: 28, tint: .secondaryLabel),
                accessoryImage: nil,
                accessoryType: .disclosureIndicator
            )
            item.handler = { _, completion in
                AudioPlayerService.shared.setPlaylist(tracks: artistTracks, startAtIndex: 0)
                completion()
            }

            // Try to load artwork from first track of artist
            if let firstUrl = artistTracks.first?.fullArtworkUrl {
                URLSession.shared.dataTask(with: firstUrl) { data, _, _ in
                    guard let data = data, let raw = UIImage(data: data) else { return }
                    let thumb = raw.roundedThumbnail(size: CGSize(width: 44, height: 44), cornerRadius: 22)
                    DispatchQueue.main.async {
                        item.setImage(thumb)
                    }
                }.resume()
            }

            items.append(item)
        }

        let section = CPListSection(
            items: items,
            header: "Artists — \(sorted.count) artists",
            sectionIndexTitle: nil
        )
        artistTemplate?.updateSections([section])
    }

    // MARK: - Error

    private func showError(message: String) {
        let item = CPListItem(
            text: "Failed to load library",
            detailText: message,
            image: icon("exclamationmark.triangle.fill", size: 28, tint: .systemRed),
            accessoryImage: nil,
            accessoryType: .none
        )
        let section = CPListSection(items: [item])
        libraryTemplate?.updateSections([section])
    }

    // MARK: - Icon Helper

    /// Returns a tinted SF Symbol as UIImage, sized for CarPlay list rows (recommended: 28–44pt)
    private func icon(_ name: String, size: CGFloat = 24, tint: UIColor = .label) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        return UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
    }
}

// MARK: - UIImage Helpers

private extension UIImage {
    /// Resize + round corners — ideal for CarPlay list row thumbnails
    func roundedThumbnail(size: CGSize, cornerRadius: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
            self.draw(in: rect)
        }
    }
}
