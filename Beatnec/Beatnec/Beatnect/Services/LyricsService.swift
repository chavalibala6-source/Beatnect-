import Foundation
import Combine

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

class LyricsService: ObservableObject {
    static let shared = LyricsService()
    
    @Published var lyrics: String? = nil
    @Published var syncedLines: [LyricLine] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var currentQuery: String?
    
    private var currentTask: URLSessionDataTask?
    private let session: URLSession
    private var debounceWorkItem: DispatchWorkItem?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        session = URLSession(configuration: config)
    }
    
    func fetchLyrics(for track: Track) {
        let artist = track.displayArtist
        let title = track.displayName
        let queryKey = "\(artist) - \(title)"
        
        if currentQuery == queryKey && (lyrics != nil || !syncedLines.isEmpty || isLoading) {
            return // Already fetched or fetching for this track
        }
        
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.performFetch(queryKey: queryKey, artist: artist, title: title)
        }
        
        debounceWorkItem = workItem
        // Delay fetch by 0.75 seconds to debounce rapid track skipping
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: workItem)
    }
    
    private func performFetch(queryKey: String, artist: String, title: String) {
        currentTask?.cancel()
        
        // Clear previous state
        DispatchQueue.main.async {
            self.currentQuery = queryKey
            self.lyrics = nil
            self.syncedLines = []
            self.error = nil
            self.isLoading = true
        }
        
        let cleanedTitle = title
        let cleanedArtist = artist
        
        // Strategy 1: Artist + Title
        guard let query = "\(cleanedArtist) \(cleanedTitle)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let lrclibURL = URL(string: "https://lrclib.net/api/search?q=\(query)") else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Invalid track information."
            }
            return
        }
        
        currentTask = session.dataTask(with: lrclibURL) { [weak self] data, response, error in
            if let error = error as? URLError, error.code == .cancelled {
                return
            }
            if let error = error {
                self?.fallbackToNextStrategy(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "NetErr1: \(error.localizedDescription)")
                return
            }
            
            // Success from LRCLIB Strategy 1
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200, let data = data {
                    do {
                        if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                            if let firstMatch = jsonArray.first(where: { ($0["plainLyrics"] as? String)?.isEmpty == false }),
                               let plainLyrics = firstMatch["plainLyrics"] as? String {
                                
                                let syncedLyrics = firstMatch["syncedLyrics"] as? String
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
                            } else {
                                self?.fallbackToNextStrategy(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "ParseErr1: No plainLyrics in array (\(jsonArray.count) items)")
                                return
                            }
                        } else {
                            self?.fallbackToNextStrategy(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "ParseErr1: Invalid JSON format")
                            return
                        }
                    } catch {
                        self?.fallbackToNextStrategy(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "ParseErr1: \(error.localizedDescription)")
                        return
                    }
                } else {
                    self?.fallbackToNextStrategy(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "HTTP1: \(httpResponse.statusCode)")
                    return
                }
            }
            self?.fallbackToNextStrategy(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "Unknown1")
        }
        currentTask?.resume()
    }
            
    private func fallbackToNextStrategy(cleanedArtist: String, cleanedTitle: String, lastError: String) {
        guard let titleQuery = cleanedTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let titleLRCLIBURL = URL(string: "https://lrclib.net/api/search?q=\(titleQuery)") else {
            self.fallbackToOVH(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "\(lastError) | TitleQueryFail")
            return
        }
        
        self.currentTask = self.session.dataTask(with: titleLRCLIBURL) { [weak self] data2, response2, error2 in
            if let error2 = error2 as? URLError, error2.code == .cancelled {
                return
            }
            if let error2 = error2 {
                self?.fallbackToOVH(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "\(lastError) | NetErr2: \(error2.localizedDescription)")
                return
            }
            
            if let httpResponse = response2 as? HTTPURLResponse {
                if httpResponse.statusCode == 200, let data2 = data2 {
                    do {
                        if let jsonArray = try JSONSerialization.jsonObject(with: data2, options: []) as? [[String: Any]] {
                            if let firstMatch = jsonArray.first(where: { ($0["plainLyrics"] as? String)?.isEmpty == false }),
                               let plainLyrics = firstMatch["plainLyrics"] as? String {
                                
                                let syncedLyrics = firstMatch["syncedLyrics"] as? String
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
                            } else {
                                self?.fallbackToOVH(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "\(lastError) | ParseErr2: No plainLyrics in array (\(jsonArray.count) items)")
                                return
                            }
                        } else {
                            self?.fallbackToOVH(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "\(lastError) | ParseErr2: Invalid JSON format")
                            return
                        }
                    } catch {
                        self?.fallbackToOVH(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "\(lastError) | ParseErr2: \(error.localizedDescription)")
                        return
                    }
                } else {
                    self?.fallbackToOVH(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "\(lastError) | HTTP2: \(httpResponse.statusCode)")
                    return
                }
            }
            self?.fallbackToOVH(cleanedArtist: cleanedArtist, cleanedTitle: cleanedTitle, lastError: "\(lastError) | Unknown2")
        }
        self.currentTask?.resume()
    }
            
    private func fallbackToOVH(cleanedArtist: String, cleanedTitle: String, lastError: String) {
        guard let ovhArtist = cleanedArtist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let ovhTitle = cleanedTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let ovhURL = URL(string: "https://api.lyrics.ovh/v1/\(ovhArtist)/\(ovhTitle)") else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "No lyrics found. [\(lastError) | OVHQueryFail]"
            }
            return
        }
        
        currentTask = session.dataTask(with: ovhURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error as? URLError, error.code == .cancelled {
                    return
                }
                if let error = error {
                    self?.error = "No lyrics found. [\(lastError) | OVHNetErr: \(error.localizedDescription)]"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    self?.error = "No lyrics found. [\(lastError) | OVHHTTP: \(httpResponse.statusCode)]"
                    return
                }
                
                guard let data = data else {
                    self?.error = "No lyrics found. [\(lastError) | OVHNoData]"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let lyricsText = json["lyrics"] as? String, !lyricsText.isEmpty {
                        self?.lyrics = lyricsText
                            .replacingOccurrences(of: "\r\n", with: "\n")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        self?.error = "No lyrics found. [\(lastError) | OVHNoLyricsText]"
                    }
                } catch {
                    self?.error = "No lyrics found. [\(lastError) | OVHParseErr]"
                }
            }
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
