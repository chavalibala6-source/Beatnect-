import Foundation
import Combine

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

class LyricsService: ObservableObject {
    @Published var lyrics: String? = nil
    @Published var syncedLines: [LyricLine] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private var currentTask: URLSessionDataTask?
    
    func fetchLyrics(for artist: String, title: String) {
        currentTask?.cancel()
        
        // Clear previous state
        self.lyrics = nil
        self.syncedLines = []
        self.error = nil
        self.isLoading = true
        
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\.mp3(?i)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^\\d{1,2}[_\\.\\s]+", with: "", options: .regularExpression)
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
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        let session = URLSession(configuration: config)
        
        currentTask = session.dataTask(with: lrclibURL) { [weak self] data, response, error in
            if let error = error as? URLError, error.code == .cancelled {
                return
            }
            
            // Success from LRCLIB
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let plainLyrics = json["plainLyrics"] as? String, !plainLyrics.isEmpty {
                        
                        let syncedLyrics = json["syncedLyrics"] as? String
                        
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            self?.lyrics = plainLyrics
                                .replacingOccurrences(of: "\r\n", with: "\n")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            if let syncedLyrics = syncedLyrics, !syncedLyrics.isEmpty {
                                self?.syncedLines = self?.parseSyncedLyrics(syncedLyrics) ?? []
                            }
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
            
            self?.currentTask = session.dataTask(with: ovhURL) { [weak self] data, response, error in
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
    }
    
    private func parseSyncedLyrics(_ syncedLyrics: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let pattern = "\\[(\\d{2,}):(\\d{2}\\.\\d{2,3})\\](.*)"
        let regex = try? NSRegularExpression(pattern: pattern)
        
        let stringLines = syncedLyrics.components(separatedBy: .newlines)
        for line in stringLines {
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex?.firstMatch(in: line, options: [], range: nsRange) {
                if let minRange = Range(match.range(at: 1), in: line),
                   let secRange = Range(match.range(at: 2), in: line),
                   let textRange = Range(match.range(at: 3), in: line) {
                    let minStr = line[minRange]
                    let secStr = line[secRange]
                    let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
                    
                    if let min = Double(minStr), let sec = Double(secStr) {
                        let time = (min * 60) + sec
                        lines.append(LyricLine(time: time, text: text))
                    }
                }
            }
        }
        return lines.sorted { $0.time < $1.time }
    }
}
