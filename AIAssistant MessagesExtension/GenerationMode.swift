import Foundation

enum GenerationMode: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "text.bubble.fill"
        case .image: return "photo.fill"
        }
    }
}
