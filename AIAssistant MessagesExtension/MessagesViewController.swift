import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {
    
    private var hostingController: UIHostingController<MainView>?
    private var detailController: UIHostingController<AnyView>?
    private var shouldStayExpanded = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📱 viewDidLoad")
    }
    
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        print("📱 willBecomeActive - selectedMessage: \(conversation.selectedMessage != nil)")
        
        // Only setup main view if we don't have any controller
        if hostingController == nil && detailController == nil {
            print("📱 No controllers found, setting up main view")
            setupView()
        }
    }
    
    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        print("📱 didSelect called")
        
        guard let url = message.url,
              let unifiedResponse = MessageHelper.decodeResponseFromURL(url: url) else {
            print("❌ Failed to decode message URL")
            return
        }
        
        print("✅ Decoded response, showing detail view")
        
        // For image responses, also get the image from the message layout
        if unifiedResponse.type == .image,
           let image = MessageHelper.decodeImageFromMessage(message: message),
           let imageResponse = unifiedResponse.imageResponse {
            let imageData = image.jpegData(compressionQuality: 1.0)
            let updatedResponse = UnifiedResponse(imageResponse: imageResponse, imageData: imageData)
            showDetailView(for: updatedResponse, conversation: conversation)
        } else {
            showDetailView(for: unifiedResponse, conversation: conversation)
        }
    }
    
    private func showDetailView(for unifiedResponse: UnifiedResponse, conversation: MSConversation) {
        print("📱 showDetailView called for type: \(unifiedResponse.type)")
        
        // Clear BOTH controllers before showing detail
        if let existing = hostingController {
            print("📱 Clearing existing main view controller")
            existing.view.removeFromSuperview()
            existing.removeFromParent()
            hostingController = nil
        }
        
        if let existing = detailController {
            print("📱 Clearing existing detail view controller")
            existing.view.removeFromSuperview()
            existing.removeFromParent()
            detailController = nil
        }
        
        let detailView: AnyView
        
        if unifiedResponse.type == .text, let textResponse = unifiedResponse.textResponse {
            detailView = AnyView(ResponseDetailView(response: textResponse, onDismiss: { [weak self] in
                self?.dismissDetailView(conversation: conversation)
            }))
        } else if unifiedResponse.type == .image,
                  let imageResponse = unifiedResponse.imageResponse,
                  let imageData = unifiedResponse.imageData,
                  let image = UIImage(data: imageData) {
            detailView = AnyView(ImageDetailView(imageResponse: imageResponse, image: image, onDismiss: { [weak self] in
                self?.dismissDetailView(conversation: conversation)
            }))
        } else {
            print("❌ Invalid unified response")
            return
        }
        
        let controller = UIHostingController(rootView: detailView)
        controller.view.backgroundColor = .white
        
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        
        self.detailController = controller
        print("📱 Detail controller set and displayed")
    }
    
    private func dismissDetailView(conversation: MSConversation) {
        print("📱 Detail view onDismiss called")
        
        // Clear detail controller
        detailController?.view.removeFromSuperview()
        detailController?.removeFromParent()
        detailController = nil
        
        // IMPORTANT: Deselect the message so it can be tapped again
        if let selectedMessage = conversation.selectedMessage {
            print("📱 Deselecting message")
            // Create a copy of the message without selection
            let newMessage = MSMessage(session: selectedMessage.session ?? MSSession())
            conversation.send(newMessage) { error in
                if let error = error {
                    print("❌ Error deselecting: \(error)")
                }
            }
        }
        
        // Recreate the main view so user sees the AI Assistant
        setupView()
        
        print("📱 Requesting compact presentation style")
        shouldStayExpanded = false
        requestPresentationStyle(.compact)
    }
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        if shouldStayExpanded && presentationStyle == .compact {
            return
        }
        
        super.willTransition(to: presentationStyle)
    }
    
    private func setupView() {
        print("📱 setupView called")
        
        // Clear any existing controller
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
        
        print("📱 Creating main view")
        
        let mainView = MainView(
            onSendText: { [weak self] response in
                self?.sendTextMessage(response: response)
            },
            onSendImage: { [weak self] imageResponse, image in
                self?.sendImageMessage(imageResponse: imageResponse, image: image)
            },
            onQuerySubmitted: { [weak self] in
                self?.shouldStayExpanded = true
                self?.requestPresentationStyle(.expanded)
            },
            onResponseReceived: { [weak self] in
                self?.shouldStayExpanded = true
            }
        )
        
        let controller = UIHostingController(rootView: mainView)
        controller.view.backgroundColor = .white
        
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        
        self.hostingController = controller
    }
    
    private func sendTextMessage(response: AIResponse) {
        guard let conversation = activeConversation else { return }
        
        let richMessage = MessageHelper.createMessage(response: response, conversation: conversation)
        
        conversation.insert(richMessage) { error in
            if let error = error {
                print("❌ Error inserting rich message: \(error)")
            } else {
                print("✅ Rich message card sent successfully")
                
                let plainText = "\(response.model.displayName): \(response.text)"
                conversation.insertText(plainText) { textError in
                    if let textError = textError {
                        print("❌ Error sending text: \(textError)")
                    } else {
                        print("✅ Plain text message sent successfully")
                    }
                }
            }
        }
        
        self.shouldStayExpanded = false
        self.requestPresentationStyle(.compact)
    }
    
    private func sendImageMessage(imageResponse: ImageResponse, image: UIImage) {
        guard let conversation = activeConversation else { return }
        
        print("🖼️ Sending image message")
        
        // Create the rich message card with the image (no image data in URL)
        let message = MessageHelper.createImageMessage(imageResponse: imageResponse, image: image, conversation: conversation)
        
        // Insert the rich message
        conversation.insert(message) { error in
            if let error = error {
                print("❌ Error inserting image message: \(error)")
            } else {
                print("✅ Image message card sent successfully")
                
                // Also insert text describing the image so it appears in the text field
                let imageDescription = "🎨 \(imageResponse.model.displayName) generated: \(imageResponse.prompt)"
                conversation.insertText(imageDescription) { textError in
                    if let textError = textError {
                        print("❌ Error sending image description text: \(textError)")
                    } else {
                        print("✅ Image description text sent successfully")
                    }
                }
            }
        }
        
        self.shouldStayExpanded = false
        self.requestPresentationStyle(.compact)
    }
}

// MARK: - Main View

struct MainView: View {
    @State private var generationMode: GenerationMode = .text
    @State private var question: String = ""
    @State private var selectedTextModel: AIModel = .claude
    @State private var selectedImageModel: ImageModel = .dalle
    @State private var textResponse: AIResponse?
    @State private var imageResponse: ImageResponse?
    @State private var generatedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingDetail = false
    @State private var detailResponse: AIResponse?
    @FocusState private var isInputFocused: Bool
    
    let onSendText: (AIResponse) -> Void
    let onSendImage: (ImageResponse, UIImage) -> Void
    let onQuerySubmitted: () -> Void
    let onResponseReceived: () -> Void
    
    func showDetailView(for response: AIResponse) {
        detailResponse = response
        showingDetail = true
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.slackPurple)
                    
                    Text("AI Assistant")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1),
                    alignment: .bottom
                )
                
                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Generation Mode Selector
                        GenerationModeSelector(selectedMode: $generationMode)
                            .onChange(of: generationMode) { _ in
                                textResponse = nil
                                imageResponse = nil
                                generatedImage = nil
                            }
                        
                        // Model Selection
                        if generationMode == .text {
                            ModelSelectionView(selectedModel: $selectedTextModel)
                        } else {
                            ImageModelSelectionView(selectedModel: $selectedImageModel)
                        }
                        
                        // Input Area
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                TextField(
                                    generationMode == .text ? "Ask a question..." : "Describe the image you want...",
                                    text: $question,
                                    axis: .vertical
                                )
                                .textFieldStyle(.plain)
                                .font(.system(size: 15))
                                .lineLimit(1...6)
                                .focused($isInputFocused)
                                .onChange(of: isInputFocused) { focused in
                                    if focused {
                                        onQuerySubmitted()
                                    }
                                }
                                
                                if !question.isEmpty {
                                    Button(action: { question = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(AppTheme.textSecondary)
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isInputFocused ? AppTheme.modeColor(for: generationMode) : AppTheme.border,
                                        lineWidth: isInputFocused ? 2 : 1
                                    )
                            )
                            
                            HStack(spacing: 8) {
                                if isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text(generationMode == .text ? "Thinking..." : "Generating...")
                                            .font(.system(size: 13))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: generateContent) {
                                    HStack(spacing: 6) {
                                        Image(systemName: generationMode.icon)
                                            .font(.system(size: 12))
                                        Text("Generate")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(
                                        question.isEmpty || isLoading
                                            ? AppTheme.textSecondary.opacity(0.3)
                                            : AppTheme.modeColor(for: generationMode)
                                    )
                                    .cornerRadius(6)
                                }
                                .disabled(question.isEmpty || isLoading)
                            }
                        }
                        .padding(16)
                        .background(AppTheme.backgroundGray)
                        .cornerRadius(8)
                        
                        // Error
                        if let error = errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.orange)
                                
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Spacer()
                                
                                Button(action: { errorMessage = nil }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Response Cards
                        if let response = textResponse {
                            SimpleResponseCard(
                                response: response,
                                availableHeight: geometry.size.height - 350,
                                onSend: {
                                    onSendText(response)
                                    self.textResponse = nil
                                },
                                onViewFull: {
                                    showDetailView(for: response)
                                }
                            )
                        }
                        
                        if let imageResp = imageResponse {
                            ImageResponseCard(
                                imageResponse: imageResp,
                                image: generatedImage,
                                availableHeight: geometry.size.height - 350,
                                onSend: {
                                    if let img = generatedImage {
                                        onSendImage(imageResp, img)
                                        self.imageResponse = nil
                                        self.generatedImage = nil
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.white)
            .sheet(isPresented: $showingDetail) {
                if let response = detailResponse {
                    ResponseDetailView(response: response, onDismiss: {
                        showingDetail = false
                    })
                }
            }
            .onChange(of: showingDetail) { newValue in
                if !newValue {
                    detailResponse = nil
                }
            }
        }
    }
    
    private func generateContent() {
        isLoading = true
        errorMessage = nil
        isInputFocused = false
        
        if generationMode == .text {
            Task {
                do {
                    let result = try await APIService.askAI(
                        question: question,
                        model: selectedTextModel,
                        userId: UIDevice.current.identifierForVendor?.uuidString
                    )
                    
                    await MainActor.run {
                        self.textResponse = result
                        self.isLoading = false
                        self.question = ""
                        onResponseReceived()
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Couldn't get a response. Please try again."
                        self.isLoading = false
                    }
                }
            }
        } else {
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                
                await MainActor.run {
                    let imgResponse = ImageResponse(
                        imageUrl: "mock://placeholder",
                        prompt: question,
                        model: selectedImageModel,
                        timestamp: Date().timeIntervalSince1970
                    )
                    
                    let mockImage = MockImageGenerator.generatePlaceholderImage(
                        prompt: question,
                        model: selectedImageModel
                    )
                    
                    self.imageResponse = imgResponse
                    self.generatedImage = mockImage
                    self.isLoading = false
                    self.question = ""
                    onResponseReceived()
                }
            }
        }
    }
}

// MARK: - Simple Response Card

struct SimpleResponseCard: View {
    let response: AIResponse
    let availableHeight: CGFloat
    let onSend: () -> Void
    let onViewFull: () -> Void
    
    private var cardHeight: CGFloat {
        min(max(availableHeight * 0.6, 150), 400)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text(response.model.icon)
                        .font(.system(size: 14))
                    
                    Text(response.model.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.modelColor(for: response.model))
                }
                
                Spacer()
                
                if !response.citations.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                        Text("\(response.citations.count)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            ScrollView(.vertical, showsIndicators: true) {
                MarkdownText(response.text, fontSize: 14, lineSpacing: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .frame(height: cardHeight)
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: {
                        UIPasteboard.general.string = response.text
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                            Text("Copy")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.modelColor(for: response.model))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.modelColor(for: response.model).opacity(0.1))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppTheme.modelColor(for: response.model).opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    if !response.citations.isEmpty {
                        Button(action: onViewFull) {
                            HStack {
                                Image(systemName: "eye")
                                    .font(.system(size: 12))
                                Text("Citations")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.modelColor(for: response.model))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.modelColor(for: response.model).opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppTheme.modelColor(for: response.model).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                
                Button(action: onSend) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12))
                        Text("Send")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.slackGreen)
                    .cornerRadius(6)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}
