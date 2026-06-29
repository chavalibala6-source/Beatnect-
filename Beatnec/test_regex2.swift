import Foundation

let title = "03 Tharagathi Gadhi SenSongsMp3.Com"
let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    .replacingOccurrences(of: "\\.mp3(?i)", with: "", options: .regularExpression)
    .replacingOccurrences(of: "^\\d{1,2}[_\\.\\s]+", with: "", options: .regularExpression)
    .replacingOccurrences(of: "_", with: " ")
    .replacingOccurrences(of: "(?i)\\s*\\(.*?\\)", with: "", options: .regularExpression)
    .replacingOccurrences(of: "(?i)\\s*\\[.*?\\]", with: "", options: .regularExpression)
    .replacingOccurrences(of: "SenSongsMp3.Com", with: "", options: .caseInsensitive)
    .trimmingCharacters(in: .whitespacesAndNewlines)

print("Cleaned: '\(cleanedTitle)'")
