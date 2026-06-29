import Foundation
import Combine

class LyricsService: ObservableObject {
    @Published var lyrics: String? = nil
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private var currentTask: URLSessionDataTask?
    
    func fetchLyrics(for artist: String, title: String) {
        currentTask?.cancel()
        
        // Clear previous state
        self.lyrics = nil
        self.error = nil
        self.isLoading = true
        
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\.mp3(?i)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^\\d{1,2}_", with: "", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "(?i)\\s*\\(.*?\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\s*\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "SenSongsMp3.Com", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cleanedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
        
        guard let encodedArtist = cleanedArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedTitle = cleanedTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let lrclibURL = URL(string: "https://lrclib.net/api/get?artist_name=\(encodedArtist)&track_name=\(encodedTitle)") else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Invalid track information"
            }
            return
        }
        
        currentTask = URLSession.shared.dataTask(with: lrclibURL) { [weak self] data, response, error in
            if let error = error as? URLError, error.code == .cancelled {
                return
            }
            
            // Success from LRCLIB
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let lyricsText = json["plainLyrics"] as? String, !lyricsText.isEmpty {
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            self?.lyrics = lyricsText
                                .replacingOccurrences(of: "\r\n", with: "\n")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        return
                    }
                } catch {
                    // Fallthrough to OVH API
                }
            }
            
            // Fallback to OVH API
            guard let ovhArtist = cleanedArtist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let ovhTitle = cleanedTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let ovhURL = URL(string: "https://api.lyrics.ovh/v1/\(ovhArtist)/\(ovhTitle)") else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.error = "No lyrics found."
                }
                return
            }
            
            self?.currentTask = URLSession.shared.dataTask(with: ovhURL) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error as? URLError, error.code == .cancelled {
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        self?.error = "No lyrics found."
                        return
                    }
                    
                    guard let data = data else {
                        self?.error = "No lyrics found."
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let lyricsText = json["lyrics"] as? String, !lyricsText.isEmpty {
                            self?.lyrics = lyricsText
                                .replacingOccurrences(of: "\r\n", with: "\n")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            self?.error = "No lyrics found."
                        }
                    } catch {
                        self?.error = "No lyrics found."
                    }
                }
            }
            self?.currentTask?.resume()
        }
        currentTask?.resume()
        
        currentTask?.resume()
    }
}
