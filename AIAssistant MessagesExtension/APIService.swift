import Foundation

class APIService {
    static let baseURL = "https://6w3udv8wz9.execute-api.us-east-1.amazonaws.com/api"
    
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
    
    static func generateImage(prompt: String, userId: String?) async throws -> ImageResponse {
        print("🎨 Starting image generation with GPT Image 1")
        
        guard let url = URL(string: "\(baseURL)/generate-image") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0  // GPT Image 1 timeout
        
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "userId": userId ?? ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🚀 Sending image generation request at: \(Date())")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            let elapsed = Date().timeIntervalSinceNow
            print("✅ Got image response after \(abs(elapsed)) seconds")
            
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
            
            let imageResponse = try JSONDecoder().decode(ImageResponse.self, from: data)
            print("✅ Successfully decoded image response")
            return imageResponse
            
        } catch let error as URLError {
            print("❌ URLError: \(error.code) - \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Unknown error: \(error)")
            throw error
        }
    }
    
    static func downloadImage(from urlString: String) async throws -> Data {
        print("📥 Downloading image from: \(urlString.prefix(100))...") // Truncate for logging
        
        // Check if it's a data URL (base64 encoded)
        if urlString.hasPrefix("data:image") {
            // Extract base64 data from data URL
            // Format: data:image/png;base64,<base64-data>
            guard let base64Range = urlString.range(of: "base64,") else {
                throw APIError.invalidURL
            }
            
            let base64String = String(urlString[base64Range.upperBound...])
            guard let imageData = Data(base64Encoded: base64String) else {
                throw APIError.decodingError
            }
            
            print("✅ Image decoded from base64, size: \(imageData.count) bytes")
            return imageData
        }
        
        // Regular URL download (fallback for backwards compatibility)
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        print("✅ Image downloaded successfully, size: \(data.count) bytes")
        return data
    }
}

enum APIError: Error {
    case invalidURL
    case serverError
    case decodingError
}
