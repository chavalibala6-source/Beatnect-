import Foundation

struct Track: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let url: String
    let downloadUrl: String?
    let size: Int?
    let mime: String?
    let uploadedAt: String?
    let artworkUrl: String?
    let artist: String?
    let album: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case downloadUrl = "download_url"
        case size
        case mime
        case uploadedAt = "uploaded_at"
        case artworkUrl = "artwork_url"
        case artist
        case album
    }
    
    var displayName: String {
        return name.replacingOccurrences(of: ".mp3", with: "")
                   .replacingOccurrences(of: ".wav", with: "")
                   .replacingOccurrences(of: "_", with: " ")
    }
    
    var displayArtist: String {
        return artist ?? "Unknown Artist"
    }
    
    var displayAlbum: String {
        return album ?? "Unknown Album"
    }
    
    var fullArtworkUrl: URL? {
        let defaultPath = "/static/images/music_thumb.jpg?v=3"
        let trimmed = artworkUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isInvalid = trimmed.isEmpty || trimmed.lowercased() == "none" || trimmed.lowercased() == "null"
        let path = isInvalid ? defaultPath : trimmed
        
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        var cleanAddress = APIService.shared.serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanAddress.hasPrefix("http://") && !cleanAddress.hasPrefix("https://") {
            cleanAddress = "http://" + cleanAddress
        }
        let prefix = path.hasPrefix("/") ? "" : "/"
        return URL(string: "\(cleanAddress)\(prefix)\(path)")
    }
}
