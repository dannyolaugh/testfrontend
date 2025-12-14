import Foundation

enum ImageModel: String, Codable, CaseIterable {
    case dalle = "dalle"
    case midjourney = "midjourney"
    case stableDiffusion = "stable-diffusion"
    case flux = "flux"
    
    var displayName: String {
        switch self {
        case .dalle: return "DALL-E 3"
        case .midjourney: return "Midjourney"
        case .stableDiffusion: return "Stable Diffusion"
        case .flux: return "Flux"
        }
    }
    
    var icon: String {
        switch self {
        case .dalle: return "🎨"
        case .midjourney: return "🖼️"
        case .stableDiffusion: return "⚡"
        case .flux: return "✨"
        }
    }
}
