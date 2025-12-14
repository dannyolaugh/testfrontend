import UIKit
import Messages

class MessageHelper {
    
    // MARK: - Text Messages
    
    static func createMessage(response: AIResponse, conversation: MSConversation) -> MSMessage {
        let message = MSMessage()
        
        let layout = MSMessageTemplateLayout()
        layout.image = createCardImage(response: response)
        layout.caption = "\(response.model.displayName) • \(response.citations.count) source\(response.citations.count == 1 ? "" : "s")"
        
        if let url = encodeTextResponseToURL(response: response) {
            message.url = url
        }
        
        message.layout = layout
        return message
    }
    
    // MARK: - Image Messages
    
    static func createImageMessage(imageResponse: ImageResponse, image: UIImage, conversation: MSConversation) -> MSMessage {
        let message = MSMessage()
        
        let layout = MSMessageTemplateLayout()
        layout.image = image
        layout.caption = "\(imageResponse.model.displayName) • Generated Image"
        
        // Use a simple URL with just metadata, no image data
        if let url = encodeImageResponseToURL(imageResponse: imageResponse) {
            message.url = url
        }
        
        message.layout = layout
        return message
    }
    
    // MARK: - Encoding
    
    static func encodeTextResponseToURL(response: AIResponse) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "aiassistant.app"
        components.path = "/response"
        
        let citationsJSON = try? JSONEncoder().encode(response.citations)
        let citationsString = citationsJSON?.base64EncodedString()
        
        components.queryItems = [
            URLQueryItem(name: "type", value: "text"),
            URLQueryItem(name: "text", value: response.text),
            URLQueryItem(name: "model", value: response.model.rawValue),
            URLQueryItem(name: "citations", value: citationsString),
            URLQueryItem(name: "timestamp", value: String(response.timestamp))
        ]
        
        return components.url
    }
    
    static func encodeImageResponseToURL(imageResponse: ImageResponse) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "aiassistant.app"
        components.path = "/response"
        
        // Don't encode image data - just metadata
        components.queryItems = [
            URLQueryItem(name: "type", value: "image"),
            URLQueryItem(name: "prompt", value: imageResponse.prompt),
            URLQueryItem(name: "model", value: imageResponse.model.rawValue),
            URLQueryItem(name: "timestamp", value: String(imageResponse.timestamp))
        ]
        
        return components.url
    }
    
    // MARK: - Decoding
    
    static func decodeResponseFromURL(url: URL) -> UnifiedResponse? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        var typeString: String?
        
        for item in queryItems {
            if item.name == "type" {
                typeString = item.value
                break
            }
        }
        
        guard let typeStr = typeString else { return nil }
        
        if typeStr == "text" {
            return decodeTextResponse(from: queryItems)
        } else if typeStr == "image" {
            return decodeImageResponse(from: queryItems)
        }
        
        return nil
    }
    
    static func decodeImageFromMessage(message: MSMessage) -> UIImage? {
        // Try to get image from the message layout
        if let layout = message.layout as? MSMessageTemplateLayout {
            return layout.image
        }
        return nil
    }
    
    private static func decodeTextResponse(from queryItems: [URLQueryItem]) -> UnifiedResponse? {
        var text: String?
        var modelRaw: String?
        var citationsString: String?
        var timestamp: TimeInterval = Date().timeIntervalSince1970
        
        for item in queryItems {
            switch item.name {
            case "text":
                text = item.value
            case "model":
                modelRaw = item.value
            case "citations":
                citationsString = item.value
            case "timestamp":
                if let value = item.value, let ts = TimeInterval(value) {
                    timestamp = ts
                }
            default:
                break
            }
        }
        
        guard let text = text,
              let modelRaw = modelRaw,
              let model = AIModel(rawValue: modelRaw) else {
            return nil
        }
        
        var citations: [Citation] = []
        if let citationsString = citationsString,
           let data = Data(base64Encoded: citationsString) {
            citations = (try? JSONDecoder().decode([Citation].self, from: data)) ?? []
        }
        
        let aiResponse = AIResponse(
            text: text,
            citations: citations,
            model: model,
            timestamp: timestamp
        )
        
        return UnifiedResponse(textResponse: aiResponse)
    }
    
    private static func decodeImageResponse(from queryItems: [URLQueryItem]) -> UnifiedResponse? {
        var prompt: String?
        var modelRaw: String?
        var timestamp: TimeInterval = Date().timeIntervalSince1970
        
        for item in queryItems {
            switch item.name {
            case "prompt":
                prompt = item.value
            case "model":
                modelRaw = item.value
            case "timestamp":
                if let value = item.value, let ts = TimeInterval(value) {
                    timestamp = ts
                }
            default:
                break
            }
        }
        
        guard let prompt = prompt,
              let modelRaw = modelRaw,
              let model = ImageModel(rawValue: modelRaw) else {
            return nil
        }
        
        let imageResponse = ImageResponse(
            imageUrl: "mock://placeholder",
            prompt: prompt,
            model: model,
            timestamp: timestamp
        )
        
        // Return without image data - we'll get it from the message layout
        return UnifiedResponse(imageResponse: imageResponse, imageData: nil)
    }
    
    // MARK: - Card Image Generation (for text responses)
    
    static func createCardImage(response: AIResponse) -> UIImage? {
        let width: CGFloat = 340
        let height: CGFloat = 220
        let size = CGSize(width: width, height: height)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            let borderColor = UIColor(red: 0.87, green: 0.87, blue: 0.87, alpha: 1.0)
            borderColor.setStroke()
            ctx.setLineWidth(1.0)
            let borderRect = CGRect(x: 0.5, y: 0.5, width: width - 1, height: height - 1)
            ctx.stroke(borderRect)
            
            let padding: CGFloat = 16
            let headerY: CGFloat = padding
            
            let iconSize: CGFloat = 14
            let iconAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
            ]
            let iconText = response.model.icon as NSString
            iconText.draw(at: CGPoint(x: padding, y: headerY), withAttributes: iconAttributes)
            
            let modelColor = getModelUIColor(for: response.model)
            let modelNameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: modelColor
            ]
            let modelNameText = response.model.displayName as NSString
            modelNameText.draw(at: CGPoint(x: padding + iconSize + 6, y: headerY + 1), withAttributes: modelNameAttributes)
            
            if !response.citations.isEmpty {
                let citationText = "\(response.citations.count)" as NSString
                let citationAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
                ]
                let citationSize = citationText.size(withAttributes: citationAttributes)
                
                let linkIconAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
                ]
                let linkIcon = "🔗" as NSString
                let linkSize = linkIcon.size(withAttributes: linkIconAttributes)
                
                let rightX = width - padding - citationSize.width - linkSize.width - 4
                linkIcon.draw(at: CGPoint(x: rightX, y: headerY), withAttributes: linkIconAttributes)
                citationText.draw(at: CGPoint(x: rightX + linkSize.width + 4, y: headerY + 1), withAttributes: citationAttributes)
            }
            
            let textY = headerY + 28
            let textHeight = height - textY - padding - 50
            let textRect = CGRect(x: padding, y: textY, width: width - (padding * 2), height: textHeight + 25)
            
            let truncatedText = truncateText(response.text, maxHeight: textHeight + 25, width: width - (padding * 2))
            let attributedText = convertMarkdownToAttributedString(truncatedText, fontSize: 14)
            attributedText.draw(in: textRect)
            
            let dividerY = height - padding - 25
            UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: padding, y: dividerY, width: width - (padding * 2), height: 1))
            
            let footerY = dividerY + 8
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
            ]
            
            let footerText = "Tap to view full response" as NSString
            let footerSize = footerText.size(withAttributes: footerAttributes)
            let centerX = (width - footerSize.width) / 2
            footerText.draw(at: CGPoint(x: centerX, y: footerY), withAttributes: footerAttributes)
        }
        
        return image
    }
    
    private static func getModelUIColor(for model: AIModel) -> UIColor {
        switch model {
        case .claude:
            return UIColor(red: 0.82, green: 0.53, blue: 0.38, alpha: 1.0)
        case .gpt4:
            return UIColor(red: 0.0, green: 0.67, blue: 0.61, alpha: 1.0)
        case .gemini:
            return UIColor(red: 0.22, green: 0.45, blue: 0.69, alpha: 1.0)
        case .perplexity:
            return UIColor(red: 0.29, green: 0.13, blue: 0.48, alpha: 1.0)
        }
    }
    
    private static func truncateText(_ text: String, maxHeight: CGFloat, width: CGFloat) -> String {
        let testAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14)
        ]
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        
        var attributesWithParagraph = testAttributes
        attributesWithParagraph[.paragraphStyle] = paragraphStyle
        
        let fullSize = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributesWithParagraph,
            context: nil
        )
        
        if fullSize.height <= maxHeight {
            return text
        }
        
        var truncated = text
        while truncated.count > 0 {
            truncated = String(truncated.dropLast(10)) + "..."
            let size = (truncated as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: attributesWithParagraph,
                context: nil
            )
            
            if size.height <= maxHeight {
                return truncated
            }
        }
        
        return "..."
    }
    
    private static func convertMarkdownToAttributedString(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        
        var processedText = text
        
        processedText = processedText.replacingOccurrences(of: "### ", with: "")
        processedText = processedText.replacingOccurrences(of: "## ", with: "")
        processedText = processedText.replacingOccurrences(of: "# ", with: "")
        processedText = processedText.replacingOccurrences(of: "###", with: "")
        processedText = processedText.replacingOccurrences(of: "##", with: "")
        processedText = processedText.replacingOccurrences(of: "#", with: "")
        processedText = processedText.replacingOccurrences(of: "**", with: "")
        processedText = processedText.replacingOccurrences(of: "__", with: "")
        processedText = processedText.replacingOccurrences(of: "*", with: "")
        processedText = processedText.replacingOccurrences(of: "_", with: "")
        
        let attributedString = NSAttributedString(string: processedText, attributes: baseAttributes)
        
        return attributedString
    }
}
