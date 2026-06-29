import Foundation

let syncedLyrics = "[00:09.07] తొలి పలుకులుతోనే కరిగిన మనసు\n[00:13.35] చిరు చినుకుల లాగే జారే"
var lines = [String]()
let pattern = "\\[(\\d{2,}):(\\d{2}\\.\\d{2,3})\\](.*)"
let regex = try? NSRegularExpression(pattern: pattern)

let stringLines = syncedLyrics.components(separatedBy: .newlines)
for line in stringLines {
    let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
    if let match = regex?.firstMatch(in: line, options: [], range: nsRange) {
        lines.append(line)
    }
}
print("Matched lines: \(lines.count)")
