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
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\.(mp3|wav|flac|m4a|aac|ogg)(?i)$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^\\d{1,2}[_\\.\\s-]+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "(?i)\\s*\\(.*?\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\s*\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "SenSongsMp3.Com", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "NaaSongs.com", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "- SenSongsMp3.co", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? name : clean
    }
    
    var displayArtist: String {
        let clean = (artist ?? "Unknown Artist").trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "(?i)\\s*\\(.*?\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\s*\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "SenSongsMp3.Com", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "NaaSongs.com", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Unknown Artist" : clean
    }
    
    var displayAlbum: String {
        let clean = (album ?? "Unknown Album").trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "(?i)\\s*\\(.*?\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\s*\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "SenSongsMp3.Com", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "NaaSongs.com", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Unknown Album" : clean
    }
    
    var fullArtworkUrl: URL? {
        let trimmed = artworkUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isInvalid = trimmed.isEmpty || trimmed.lowercased() == "none" || trimmed.lowercased() == "null"
        guard !isInvalid else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        var cleanAddress = APIService.shared.serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanAddress.hasPrefix("http://") && !cleanAddress.hasPrefix("https://") {
            cleanAddress = "http://" + cleanAddress
        }
        let prefix = trimmed.hasPrefix("/") ? "" : "/"
        return URL(string: "\(cleanAddress)\(prefix)\(trimmed)")
    }
}
