import Foundation

let titles = [
    "03 Tharagathi Gadhi SenSongsMp3.Com",
    "Track Name - www.sensongsMp3.co",
    "Track Name - www.NaaSongs.in",
    "Track Name www.sensongsmp3.com"
]

for title in titles {
    let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\.(mp3|wav|flac|m4a|aac|ogg)(?i)$", with: "", options: .regularExpression)
        .replacingOccurrences(of: "^\\d{1,2}[_\\.\\s-]+", with: "", options: .regularExpression)
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "(?i)\\s*\\(.*?\\)", with: "", options: .regularExpression)
        .replacingOccurrences(of: "(?i)\\s*\\[.*?\\]", with: "", options: .regularExpression)
        .replacingOccurrences(of: "(?i)\\s*-?\\s*(www\\.)?(sensongsmp3|naasongs)\\.(com|co|in|net|org)", with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    print("Original: '\(title)' -> Cleaned: '\(clean)'")
}
