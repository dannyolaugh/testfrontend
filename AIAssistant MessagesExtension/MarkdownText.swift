import SwiftUI

struct MarkdownText: View {
    let text: String
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    
    init(_ text: String, fontSize: CGFloat = 15, lineSpacing: CGFloat = 4) {
        self.text = text
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            // Use native Markdown support on iOS 15+
            Text(LocalizedStringKey(text))
                .font(.system(size: fontSize))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(lineSpacing)
                .textSelection(.enabled)
        } else {
            // Fallback for older iOS versions
            Text(text)
                .font(.system(size: fontSize))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(lineSpacing)
        }
    }
}
