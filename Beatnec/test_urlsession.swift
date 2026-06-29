import Foundation

let url = URL(string: "https://lrclib.net/api/search?q=Kaala%20Bhairava%20Tharagathi%20Gadhi")!
var request = URLRequest(url: url)

let semaphore = DispatchSemaphore(value: 0)

URLSession.shared.dataTask(with: request) { data, response, error in
    if let httpResponse = response as? HTTPURLResponse {
        print("Status code: \(httpResponse.statusCode)")
    }
    if let data = data, let str = String(data: data, encoding: .utf8) {
        print("Data length: \(data.count)")
        print("Data preview: \(str.prefix(200))")
    }
    if let error = error {
        print("Error: \(error)")
    }
    semaphore.signal()
}.resume()

semaphore.wait()
