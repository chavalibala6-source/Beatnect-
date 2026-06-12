import Foundation

class APIService: ObservableObject {
    static let shared = APIService()
    
    @Published var serverAddress: String {
        didSet {
            UserDefaults.standard.set(serverAddress, forKey: "gmp_server_address")
        }
    }
    
    @Published var documentName: String {
        didSet {
            UserDefaults.standard.set(documentName, forKey: "gmp_document_name")
        }
    }
    
    private init() {
        // Fallback to noteslook.shop production server URL
        self.serverAddress = UserDefaults.standard.string(forKey: "gmp_server_address") ?? "https://noteslook.shop"
        self.documentName = UserDefaults.standard.string(forKey: "gmp_document_name") ?? "global"
    }
    
    func fetchTracks(completion: @escaping (Result<[Track], Error>) -> Void) {
        // Clean URL input
        var cleanAddress = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanAddress.hasPrefix("http://") && !cleanAddress.hasPrefix("https://") {
            cleanAddress = "http://" + cleanAddress
        }
        
        guard let encodedDocName = documentName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(cleanAddress)/music_tracks?doc=\(encodedDocName)") else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Server or Document URL"])))
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
