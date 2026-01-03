import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {
    
    private var hostingController: UIHostingController<AnyView>?
    private var currentGenerationMode: GenerationMode = .text // Preserve mode
    private var currentQuestion: String = "" // Preserve question
    private var shouldRefocusTextField = false // Track if we need to refocus after expansion
    
    // Preserve selected models
    private var currentTextModel: AIModel = .claude
    private var currentImageModel: ImageModel = .dalle
    
    // Preserve responses
    private var currentTextResponse: AIResponse?
    private var currentImageResponse: ImageResponse?
    private var currentGeneratedImage: UIImage?
    
    // Track loading state
    private var isGenerating = false
    private var currentGenerationTask: Task<Void, Never>?
    
    // Track if we're currently showing a detail view
    private var isShowingDetailView = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📱 viewDidLoad")
    }
    
    // MARK: - Core Lifecycle Methods
    
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        print("📱 willBecomeActive - presentationStyle: \(presentationStyle.rawValue)")
        
        // Present the appropriate view based on presentation style
        presentViewController(for: conversation, with: presentationStyle)
    }
    
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        print("📱 didTransition to: \(presentationStyle.rawValue)")
        
        guard let conversation = activeConversation else { return }
        
        // Update view based on new presentation style
        presentViewController(for: conversation, with: presentationStyle)
    }
    
    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        print("📱 didSelect - message selected")
        
        // When a message is selected, expand to full screen
        requestPresentationStyle(.expanded)
    }
    
    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
        print("📱 didResignActive")
    }
    
    // MARK: - View Presentation Logic
    
    private func presentViewController(for conversation: MSConversation, with presentationStyle: MSMessagesAppPresentationStyle) {
        print("📱 presentViewController - style: \(presentationStyle.rawValue), selectedMessage: \(conversation.selectedMessage != nil), isShowingDetailView: \(isShowingDetailView)")
        
        // SPECIAL CASE: If we're going to compact mode, a message is selected,
        // AND we were showing a detail view, it means user swiped down. Dismiss entirely.
        if presentationStyle == .compact && conversation.selectedMessage != nil && isShowingDetailView {
            print("📱 User swiped down on detail view - dismissing extension entirely")
            isShowingDetailView = false
            dismiss()
            return
        }
        
        // Clean up existing view
        cleanupView()
        
        // Decision tree based on GamePigeon pattern:
        // - Compact mode: ALWAYS show main view (selection UI)
        // - Expanded mode with selected message: Show detail view
        // - Expanded mode without selected message: Show main view
        
        if presentationStyle == .compact {
            // Compact = main/selection view (like GamePigeon game selection)
            print("📱 Presenting main view (compact)")
            isShowingDetailView = false
            presentMainView(conversation: conversation)
        } else {
            // Expanded mode
            if let selectedMessage = conversation.selectedMessage {
                // Message is selected - show the detail view
                print("📱 Presenting detail view (expanded with message)")
                isShowingDetailView = true
                presentDetailView(for: selectedMessage, conversation: conversation)
            } else {
                // No message selected - show main view
                print("📱 Presenting main view (expanded, no message)")
                isShowingDetailView = false
                presentMainView(conversation: conversation)
            }
        }
    }
    
    // MARK: - Main View
    
    private func presentMainView(conversation: MSConversation) {
        print("📱 Creating main view with mode: \(currentGenerationMode.rawValue), shouldRefocus: \(shouldRefocusTextField)")
        
        let mainView = MainView(
            initialMode: currentGenerationMode,
            initialQuestion: currentQuestion,
            initialTextModel: currentTextModel,
            initialImageModel: currentImageModel,
            initialTextResponse: currentTextResponse,
            initialImageResponse: currentImageResponse,
            initialGeneratedImage: currentGeneratedImage,
            isLoading: isGenerating,
            shouldFocusTextField: shouldRefocusTextField,
            onSendText: { [weak self] response in
                self?.sendTextMessage(response: response, conversation: conversation)
            },
            onSendImage: { [weak self] imageResponse, image in
                self?.sendImageMessage(imageResponse: imageResponse, image: image, conversation: conversation)
            },
            onQuerySubmitted: { [weak self] in
                // Expand when user taps text field in compact mode
                if self?.presentationStyle == .compact {
                    self?.shouldRefocusTextField = true
                    self?.requestPresentationStyle(.expanded)
                }
            },
            onGenerate: { [weak self] question, mode, textModel, imageModel in
                // Handle generation at view controller level
                self?.generateContent(question: question, mode: mode, textModel: textModel, imageModel: imageModel, conversation: conversation)
            },
            onResponseReceived: { },
            onStateChanged: { [weak self] mode, question in
                // Preserve state when it changes
                self?.currentGenerationMode = mode
                self?.currentQuestion = question
            },
            onModelChanged: { [weak self] textModel, imageModel in
                // Preserve model selections
                self?.currentTextModel = textModel
                self?.currentImageModel = imageModel
            },
            onResponseStateChanged: { [weak self] textResponse, imageResponse, image in
                // Preserve responses when they change
                self?.currentTextResponse = textResponse
                self?.currentImageResponse = imageResponse
                self?.currentGeneratedImage = image
            }
        )
        
        // Reset refocus flag after creating view
        shouldRefocusTextField = false
        
        let controller = UIHostingController(rootView: AnyView(mainView))
        controller.view.backgroundColor = .white
        
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        
        hostingController = controller
        print("📱 Main view presented")
    }
    
    // MARK: - Detail View
    
    private func presentDetailView(for message: MSMessage, conversation: MSConversation) {
        print("📱 Creating detail view for message")
        
        guard let url = message.url,
              let unifiedResponse = MessageHelper.decodeResponseFromURL(url: url) else {
            print("❌ Failed to decode message URL - showing main view")
            presentMainView(conversation: conversation)
            return
        }
        
        // Handle image responses - need to get image data
        if unifiedResponse.type == .image,
           let imageResponse = unifiedResponse.imageResponse {
            
            // Try to get image from message layout first
            if let layoutImage = MessageHelper.decodeImageFromMessage(message: message) {
                let imageData = layoutImage.jpegData(compressionQuality: 1.0)
                let updatedResponse = UnifiedResponse(imageResponse: imageResponse, imageData: imageData)
                showDetailContent(for: updatedResponse, conversation: conversation)
            } else if imageResponse.imageUrl != "mock://placeholder" {
                // Download image if not in layout
                print("📥 Downloading image from URL")
                showLoadingView()
                
                Task {
                    do {
                        let imageData = try await APIService.downloadImage(from: imageResponse.imageUrl)
                        let updatedResponse = UnifiedResponse(imageResponse: imageResponse, imageData: imageData)
                        
                        await MainActor.run {
                            self.showDetailContent(for: updatedResponse, conversation: conversation)
                        }
                    } catch {
                        print("❌ Failed to download image: \(error)")
                        await MainActor.run {
                            self.presentMainView(conversation: conversation)
                        }
                    }
                }
            } else {
                print("❌ No image data available")
                presentMainView(conversation: conversation)
            }
        } else {
            // Text response - show immediately
            showDetailContent(for: unifiedResponse, conversation: conversation)
        }
    }
    
    private func showDetailContent(for unifiedResponse: UnifiedResponse, conversation: MSConversation) {
        print("📱 Showing detail content for type: \(unifiedResponse.type)")
        
        let detailView: AnyView
        
        if unifiedResponse.type == .text, let textResponse = unifiedResponse.textResponse {
            detailView = AnyView(
                ResponseDetailView(
                    response: textResponse,
                    onDismiss: { [weak self] in
                        print("📱 Detail view dismissed - dismissing entire extension")
                        // Dismiss the entire extension
                        self?.dismiss()
                    }
                )
                .interactiveDismissDisabled(false) // Allow swipe to dismiss
            )
        } else if unifiedResponse.type == .image,
                  let imageResponse = unifiedResponse.imageResponse,
                  let imageData = unifiedResponse.imageData,
                  let image = UIImage(data: imageData) {
            detailView = AnyView(
                ImageDetailView(
                    imageResponse: imageResponse,
                    image: image,
                    onDismiss: { [weak self] in
                        print("📱 Detail view dismissed - dismissing entire extension")
                        // Dismiss the entire extension
                        self?.dismiss()
                    }
                )
                .interactiveDismissDisabled(false) // Allow swipe to dismiss
            )
        } else {
            print("❌ Invalid unified response")
            presentMainView(conversation: conversation)
            return
        }
        
        let controller = UIHostingController(rootView: detailView)
        controller.view.backgroundColor = .white
        
        // Important: Set presentation style to allow swipe-to-dismiss
        controller.modalPresentationStyle = .automatic
        
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        
        hostingController = controller
        print("📱 Detail content displayed")
    }
    
    private func showLoadingView() {
        let loadingView = AnyView(
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading...")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
        )
        
        let controller = UIHostingController(rootView: loadingView)
        controller.view.backgroundColor = .white
        
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        
        hostingController = controller
    }
    
    private func cleanupView() {
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
    }
    
    // MARK: - Message Sending
    
    private func generateContent(question: String, mode: GenerationMode, textModel: AIModel, imageModel: ImageModel, conversation: MSConversation) {
        print("📱 Starting generation at controller level")
        
        // Cancel any existing task
        currentGenerationTask?.cancel()
        
        isGenerating = true
        
        // Recreate view to show loading state
        presentMainView(conversation: conversation)
        
        if mode == .text {
            currentGenerationTask = Task { [weak self] in
                do {
                    let result = try await APIService.askAI(
                        question: question,
                        model: textModel,
                        userId: UIDevice.current.identifierForVendor?.uuidString
                    )
                    
                    guard !Task.isCancelled else { return }
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.currentTextResponse = result
                        self.isGenerating = false
                        self.currentGenerationTask = nil
                        // Keep question so user can query again or try different model
                        // Recreate view with response
                        self.presentMainView(conversation: conversation)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        print("❌ Generation error: \(error)")
                        self.isGenerating = false
                        self.currentGenerationTask = nil
                        // Keep question so user can retry
                        // Recreate view to clear loading state
                        self.presentMainView(conversation: conversation)
                    }
                }
            }
        } else {
            currentGenerationTask = Task { [weak self] in
                do {
                    print("🎨 Starting real image generation with DALL-E 3")
                    
                    let imgResponse = try await APIService.generateImage(
                        prompt: question,
                        userId: UIDevice.current.identifierForVendor?.uuidString
                    )
                    
                    guard !Task.isCancelled else { return }
                    
                    print("✅ Image generation API call successful, imageUrl: \(imgResponse.imageUrl)")
                    
                    let imageData = try await APIService.downloadImage(from: imgResponse.imageUrl)
                    
                    guard !Task.isCancelled else { return }
                    
                    guard let image = UIImage(data: imageData) else {
                        throw APIError.decodingError
                    }
                    
                    print("✅ Image downloaded and converted to UIImage")
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.currentImageResponse = imgResponse
                        self.currentGeneratedImage = image
                        self.isGenerating = false
                        self.currentGenerationTask = nil
                        // Keep question so user can query again or try different model
                        // Recreate view with response
                        self.presentMainView(conversation: conversation)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        print("❌ Image generation failed: \(error)")
                        self.isGenerating = false
                        self.currentGenerationTask = nil
                        // Keep question so user can retry
                        // Recreate view to clear loading state
                        self.presentMainView(conversation: conversation)
                    }
                }
            }
        }
    }
    
    // MARK: - Message Sending
    
    private func sendTextMessage(response: AIResponse, conversation: MSConversation) {
        print("📱 Sending text message")
        
        let richMessage = MessageHelper.createMessage(response: response, conversation: conversation)
        
        conversation.insert(richMessage) { error in
            if let error = error {
                print("❌ Error inserting rich message: \(error)")
            } else {
                print("✅ Rich message card sent successfully")
            }
        }
        
        // Clear the response after sending
        currentTextResponse = nil
        
        // Collapse after sending
        requestPresentationStyle(.compact)
    }
    
    private func sendImageMessage(imageResponse: ImageResponse, image: UIImage, conversation: MSConversation) {
        print("📱 Sending image message")
        
        let message = MessageHelper.createImageMessage(
            imageResponse: imageResponse,
            image: image,
            conversation: conversation
        )
        
        conversation.insert(message) { error in
            if let error = error {
                print("❌ Error inserting image message: \(error)")
            } else {
                print("✅ Image message card sent successfully")
            }
        }
        
        // Clear the responses after sending
        currentImageResponse = nil
        currentGeneratedImage = nil
        
        // Collapse after sending
        requestPresentationStyle(.compact)
    }
}

// MARK: - Main View

struct MainView: View {
    @State private var generationMode: GenerationMode
    @State private var question: String
    @State private var selectedTextModel: AIModel
    @State private var selectedImageModel: ImageModel
    @State private var textResponse: AIResponse?
    @State private var imageResponse: ImageResponse?
    @State private var generatedImage: UIImage?
    let isLoading: Bool // Now comes from controller
    @State private var errorMessage: String?
    @State private var showingDetail = false
    @State private var detailResponse: AIResponse?
    @FocusState private var isInputFocused: Bool
    
    let shouldFocusTextField: Bool
    let onSendText: (AIResponse) -> Void
    let onSendImage: (ImageResponse, UIImage) -> Void
    let onQuerySubmitted: () -> Void
    let onGenerate: (String, GenerationMode, AIModel, ImageModel) -> Void
    let onResponseReceived: () -> Void
    let onStateChanged: (GenerationMode, String) -> Void
    let onModelChanged: (AIModel, ImageModel) -> Void
    let onResponseStateChanged: (AIResponse?, ImageResponse?, UIImage?) -> Void
    
    init(
        initialMode: GenerationMode = .text,
        initialQuestion: String = "",
        initialTextModel: AIModel = .claude,
        initialImageModel: ImageModel = .dalle,
        initialTextResponse: AIResponse? = nil,
        initialImageResponse: ImageResponse? = nil,
        initialGeneratedImage: UIImage? = nil,
        isLoading: Bool = false,
        shouldFocusTextField: Bool = false,
        onSendText: @escaping (AIResponse) -> Void,
        onSendImage: @escaping (ImageResponse, UIImage) -> Void,
        onQuerySubmitted: @escaping () -> Void,
        onGenerate: @escaping (String, GenerationMode, AIModel, ImageModel) -> Void,
        onResponseReceived: @escaping () -> Void,
        onStateChanged: @escaping (GenerationMode, String) -> Void,
        onModelChanged: @escaping (AIModel, ImageModel) -> Void,
        onResponseStateChanged: @escaping (AIResponse?, ImageResponse?, UIImage?) -> Void
    ) {
        _generationMode = State(initialValue: initialMode)
        _question = State(initialValue: initialQuestion)
        _selectedTextModel = State(initialValue: initialTextModel)
        _selectedImageModel = State(initialValue: initialImageModel)
        _textResponse = State(initialValue: initialTextResponse)
        _imageResponse = State(initialValue: initialImageResponse)
        _generatedImage = State(initialValue: initialGeneratedImage)
        self.isLoading = isLoading
        self.shouldFocusTextField = shouldFocusTextField
        self.onSendText = onSendText
        self.onSendImage = onSendImage
        self.onQuerySubmitted = onQuerySubmitted
        self.onGenerate = onGenerate
        self.onResponseReceived = onResponseReceived
        self.onStateChanged = onStateChanged
        self.onModelChanged = onModelChanged
        self.onResponseStateChanged = onResponseStateChanged
    }
    
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
                            .onChange(of: generationMode) { newMode in
                                // Only clear the response for the mode we're switching FROM
                                // This preserves responses when switching tabs
                                onStateChanged(newMode, question)
                            }
                        
                        // Model Selection
                        if generationMode == .text {
                            ModelSelectionView(selectedModel: $selectedTextModel)
                                .onChange(of: selectedTextModel) { newModel in
                                    onModelChanged(newModel, selectedImageModel)
                                }
                        } else {
                            ImageModelSelectionView(selectedModel: $selectedImageModel)
                                .onChange(of: selectedImageModel) { newModel in
                                    onModelChanged(selectedTextModel, newModel)
                                }
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
                                .foregroundColor(AppTheme.textPrimary) // Force dark text color
                                .lineLimit(1...6)
                                .focused($isInputFocused)
                                .onChange(of: isInputFocused) { focused in
                                    if focused {
                                        onQuerySubmitted()
                                    }
                                }
                                .onChange(of: question) { newQuestion in
                                    onStateChanged(generationMode, newQuestion)
                                }
                                
                                if !question.isEmpty {
                                    Button(action: {
                                        question = ""
                                        onStateChanged(generationMode, "")
                                    }) {
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
                                
                                Button(action: {
                                    // Call controller-level generation
                                    onGenerate(question, generationMode, selectedTextModel, selectedImageModel)
                                    isInputFocused = false
                                }) {
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
                        
                        // Response Cards - only show responses for the current mode
                        if generationMode == .text {
                            if let response = textResponse {
                                SimpleResponseCard(
                                    response: response,
                                    availableHeight: geometry.size.height - 350,
                                    onSend: {
                                        onSendText(response)
                                        self.textResponse = nil
                                        onResponseStateChanged(nil, imageResponse, generatedImage)
                                    },
                                    onViewFull: {
                                        showDetailView(for: response)
                                    }
                                )
                            }
                        } else {
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
                                            onResponseStateChanged(textResponse, nil, nil)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.white)
            .preferredColorScheme(.light) // Force light mode
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
            .onAppear {
                // Auto-focus text field if requested (after expansion)
                if shouldFocusTextField {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInputFocused = true
                    }
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
