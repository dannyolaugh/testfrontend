import SwiftUI

struct AppTheme {
    // Slack-inspired Colors
    static let slackPurple = Color(red: 0.29, green: 0.13, blue: 0.48)
    static let slackGreen = Color(red: 0.0, green: 0.67, blue: 0.61)
    static let slackBlue = Color(red: 0.22, green: 0.45, blue: 0.69)
    static let slackYellow = Color(red: 0.93, green: 0.70, blue: 0.13)
    static let slackRed = Color(red: 0.88, green: 0.27, blue: 0.31)
    
    // Neutral Colors
    static let textPrimary = Color(red: 0.11, green: 0.11, blue: 0.11)
    static let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.45)
    static let border = Color(red: 0.87, green: 0.87, blue: 0.87)
    static let backgroundGray = Color(red: 0.97, green: 0.97, blue: 0.97)
    
    // Model Colors (subtle)
    static func modelColor(for model: AIModel) -> Color {
        switch model {
        case .claude: return Color(red: 0.82, green: 0.53, blue: 0.38)
        case .gpt4: return slackGreen
        case .gemini: return slackBlue
        case .perplexity: return slackPurple
        }
    }
    
    // Image Model Colors
    static func imageModelColor(for model: ImageModel) -> Color {
        switch model {
        case .dalle: return Color(red: 0.82, green: 0.53, blue: 0.38)
        }
    }
    
    // Generation Mode Colors
    static func modeColor(for mode: GenerationMode) -> Color {
        switch mode {
        case .text: return slackGreen
        case .image: return slackPurple
        }
    }
}

// Clean card style
struct CleanCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func cleanCard() -> some View {
        modifier(CleanCardModifier())
    }
}
