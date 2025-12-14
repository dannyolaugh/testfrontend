import Foundation

class APIService {
    static let baseURL = "https://bbkgjkxpjk.execute-api.us-east-1.amazonaws.com/api"
    
    // Custom URLSession with longer timeout
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0  // 60 seconds for request
        config.timeoutIntervalForResource = 120.0  // 120 seconds total
        return URLSession(configuration: config)
    }()
    
    static func askAI(question: String, model: AIModel, userId: String?) async throws -> AIResponse {
        print("⏱️ Using session with timeout: \(session.configuration.timeoutIntervalForRequest) seconds")
        
        guard let url = URL(string: "\(baseURL)/ask") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0  // 60 second timeout
        
        let requestBody = AskRequest(question: question, model: model, userId: userId)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("🚀 Starting request at: \(Date())")
        print("🚀 Model: \(model.rawValue)")
        
        do {
            // Use custom session instead of shared
            let (data, response) = try await session.data(for: request)
            
            let elapsed = Date().timeIntervalSinceNow
            print("✅ Got response after \(abs(elapsed)) seconds")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Not an HTTP response")
                throw APIError.serverError
            }
            
            print("📊 Status code: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Server error - status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Response body: \(responseString)")
                }
                throw APIError.serverError
            }
            
            let aiResponse = try JSONDecoder().decode(AIResponse.self, from: data)
            print("✅ Successfully decoded response")
            return aiResponse
            
        } catch let error as URLError {
            print("❌ URLError: \(error.code) - \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            throw error
        } catch {
            print("❌ Unknown error: \(error)")
            throw error
        }
    }
}

enum APIError: Error {
    case invalidURL
    case serverError
    case decodingError
}
