import Foundation

class APIService: ObservableObject {
    static let shared = APIService()
    
    @Published var serverAddress: String {
        didSet {
            UserDefaults.standard.set(serverAddress, forKey: "gmp_server_address")
        }
    }
    
    private init() {
        // Fallback to localhost (simulator) or frame.com local domain
        self.serverAddress = UserDefaults.standard.string(forKey: "gmp_server_address") ?? "http://localhost:5001"
    }
    
    func fetchTracks(completion: @escaping (Result<[Track], Error>) -> Void) {
        // Clean URL input
        var cleanAddress = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanAddress.hasPrefix("http://") && !cleanAddress.hasPrefix("https://") {
            cleanAddress = "http://" + cleanAddress
        }
        
        guard let url = URL(string: "\(cleanAddress)/music_tracks") else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Server URL"])))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "APIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let tracks = try decoder.decode([Track].self, from: data)
                DispatchQueue.main.async { completion(.success(tracks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        task.resume()
    }
}
