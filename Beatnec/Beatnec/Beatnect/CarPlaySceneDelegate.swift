import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    var listTemplate: CPListTemplate?
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        // Setup initial list template
        let listTemplate = CPListTemplate(title: "Beatnect Library", sections: [])
        self.listTemplate = listTemplate
        
        // Push root list template
        interfaceController.setRootTemplate(listTemplate, animated: true, completion: nil)
        
        // Fetch tracks and build items
        loadTracks()
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        self.listTemplate = nil
    }
    
    func loadTracks() {
        APIService.shared.fetchTracks { [weak self] result in
            switch result {
            case .success(let tracks):
                self?.buildListTemplate(with: tracks)
            case .failure(let error):
                print("Failed to fetch CarPlay tracks: \(error)")
                self?.showErrorTemplate(message: error.localizedDescription)
            }
        }
    }
    
    private func buildListTemplate(with tracks: [Track]) {
        var items = [CPListItem]()
        for (index, track) in tracks.enumerated() {
            let item = CPListItem(text: track.displayName, detailText: track.displayArtist)
            
            // Set playback start handler
            item.handler = { _, completion in
                AudioPlayerService.shared.setPlaylist(tracks: tracks, startAtIndex: index)
                completion()
            }
            
            // Load artwork icon asynchronously if available
            if let artworkUrlString = track.artworkUrl, let url = URL(string: artworkUrlString) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            item.setImage(image)
                        }
                    }
                }.resume()
            } else {
                if let systemIcon = UIImage(systemName: "music.note") {
                    item.setImage(systemIcon)
                }
            }
            
            items.append(item)
        }
        
        let section = CPListSection(items: items)
        listTemplate?.updateSections([section])
    }
    
    private func showErrorTemplate(message: String) {
        let errorItem = CPListItem(text: "Error loading library", detailText: "Ensure Flask Server is running: \(message)")
        let section = CPListSection(items: [errorItem])
        listTemplate?.updateSections([section])
    }
}
