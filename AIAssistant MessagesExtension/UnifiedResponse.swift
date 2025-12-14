import Foundation

enum ResponseType: String, Codable {
    case text
    case image
}

struct UnifiedResponse: Codable {
    let type: ResponseType
    let textResponse: AIResponse?
    let imageResponse: ImageResponse?
    let imageData: Data? // Store image as data
    
    init(textResponse: AIResponse) {
        self.type = .text
        self.textResponse = textResponse
        self.imageResponse = nil
        self.imageData = nil
    }
    
    init(imageResponse: ImageResponse, imageData: Data?) {
        self.type = .image
        self.textResponse = nil
        self.imageResponse = imageResponse
        self.imageData = imageData
    }
}
