import Foundation

let jsonString = """
[{"id":9438982,"name":"Tharagathi Gadhi","trackName":"Tharagathi Gadhi","artistName":"Kaala Bhairava","albumName":"Tharagathi Gadhi","duration":213.0,"instrumental":false,"plainLyrics":"తొలి పలుకులుతోనే కరిగిన మనసు","syncedLyrics":"[00:09.07] తొలి పలుకులుతోనే కరిగిన మనసు","lyricsfile":null}]
"""

let data = jsonString.data(using: .utf8)!

do {
    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
       let firstMatch = jsonArray.first(where: { ($0["plainLyrics"] as? String)?.isEmpty == false }),
       let plainLyrics = firstMatch["plainLyrics"] as? String {
        print("Success: \(plainLyrics)")
    } else {
        print("Failed to parse JSON")
    }
} catch {
    print("Error: \(error)")
}
