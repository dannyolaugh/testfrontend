import Foundation

enum AIModel: String, Codable, CaseIterable {
    case claude = "claude"
    case gpt4 = "gpt4"
    case gemini = "gemini"
    case perplexity = "perplexity"
    
    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .gpt4: return "GPT-4"
        case .gemini: return "Gemini"
        case .perplexity: return "Perplexity"
        }
    }
    
    var icon: String {
        switch self {
        case .claude: return "🤖"
        case .gpt4: return "💬"
        case .gemini: return "✨"
        case .perplexity: return "🔍"
        }
    }
}

struct Citation: Codable {
    let title: String
    let url: String
    let snippet: String?
}

struct AIResponse: Codable {
    let text: String
    let citations: [Citation]
    let model: AIModel
    let timestamp: TimeInterval
}

struct AskRequest: Codable {
    let question: String
    let model: AIModel
    let userId: String?
}
