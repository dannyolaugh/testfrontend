import Foundation

enum ImageModel: String, Codable, CaseIterable {
    case dalle = "dalle"
    
    var displayName: String {
        switch self {
        case .dalle: return "DALL-E 3"
        }
    }
    
    var icon: String {
        switch self {
        case .dalle: return "🎨"
        }
    }
}
