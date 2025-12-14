import Foundation

struct ImageResponse: Codable {
    let imageUrl: String
    let prompt: String
    let model: ImageModel
    let timestamp: TimeInterval
}
