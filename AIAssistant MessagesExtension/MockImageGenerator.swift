import UIKit

class MockImageGenerator {
    
    static func generatePlaceholderImage(prompt: String, model: ImageModel) -> UIImage? {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Create gradient background based on model
            let colors = getGradientColors(for: model)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [colors.0.cgColor, colors.1.cgColor] as CFArray,
                locations: [0.0, 1.0]
            )!
            
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Add model icon
            let iconSize: CGFloat = 80
            let iconAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: iconSize),
            ]
            let iconText = model.icon as NSString
            let iconBounds = iconText.boundingRect(with: size, options: [], attributes: iconAttributes, context: nil)
            let iconX = (size.width - iconBounds.width) / 2
            let iconY = (size.height - iconBounds.height) / 2 - 60
            iconText.draw(at: CGPoint(x: iconX, y: iconY), withAttributes: iconAttributes)
            
            // Add model name
            let modelNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let modelName = model.displayName as NSString
            let modelBounds = modelName.boundingRect(with: size, options: [], attributes: modelNameAttributes, context: nil)
            let modelX = (size.width - modelBounds.width) / 2
            let modelY = iconY + iconBounds.height + 20
            modelName.draw(at: CGPoint(x: modelX, y: modelY), withAttributes: modelNameAttributes)
            
            // Add "Generated Image" text
            let generatedTextAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let generatedText = "Generated Image" as NSString
            let generatedBounds = generatedText.boundingRect(with: size, options: [], attributes: generatedTextAttributes, context: nil)
            let generatedX = (size.width - generatedBounds.width) / 2
            let generatedY = modelY + modelBounds.height + 15
            generatedText.draw(at: CGPoint(x: generatedX, y: generatedY), withAttributes: generatedTextAttributes)
            
            // Add truncated prompt at bottom
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byTruncatingTail
            
            let promptAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .paragraphStyle: paragraphStyle
            ]
            
            let truncatedPrompt = prompt.prefix(100)
            let promptText = "\"\(truncatedPrompt)\(prompt.count > 100 ? "..." : "")\"" as NSString
            let promptRect = CGRect(x: 40, y: size.height - 80, width: size.width - 80, height: 60)
            promptText.draw(in: promptRect, withAttributes: promptAttributes)
        }
        
        return image
    }
    
    private static func getGradientColors(for model: ImageModel) -> (UIColor, UIColor) {
        switch model {
        case .dalle:
            return (
                UIColor(red: 0.82, green: 0.53, blue: 0.38, alpha: 1.0),
                UIColor(red: 0.92, green: 0.63, blue: 0.48, alpha: 1.0)
            )
        case .midjourney:
            return (
                UIColor(red: 0.29, green: 0.13, blue: 0.48, alpha: 1.0),
                UIColor(red: 0.49, green: 0.33, blue: 0.68, alpha: 1.0)
            )
        case .stableDiffusion:
            return (
                UIColor(red: 0.93, green: 0.70, blue: 0.13, alpha: 1.0),
                UIColor(red: 1.0, green: 0.80, blue: 0.33, alpha: 1.0)
            )
        case .flux:
            return (
                UIColor(red: 0.22, green: 0.45, blue: 0.69, alpha: 1.0),
                UIColor(red: 0.42, green: 0.65, blue: 0.89, alpha: 1.0)
            )
        }
    }
}
