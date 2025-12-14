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
        // Don't automatically setup view - let willBecomeActive or didSelect handle it
        // This prevents the issue where viewDidLoad is called after didSelect
    }
    
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        print("📱 willBecomeActive - selectedMessage: \(conversation.selectedMessage != nil)")
        print("📱 willBecomeActive - hostingController: \(hostingController != nil), detailController: \(detailController != nil)")
        print("📱 willBecomeActive - view.subviews.count: \(view.subviews.count), children.count: \(children.count)")
        
        // If there's a selected message, show its detail
        if let message = conversation.selectedMessage,
           let url = message.url,
           let response = MessageHelper.decodeResponseFromURL(url: url) {
            print("📱 Found selected message, showing detail")
            showResponseDetailView(for: response)
            return
        }
        
        // Only setup view if we don't have any controller at all AND no child view controllers
        if hostingController == nil && detailController == nil && children.isEmpty {
            print("📱 No controllers found, setting up main view")
            setupView()
        } else {
            print("📱 Controller exists or has children, skipping setup")
        }
    }
    
    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        print("📱 didSelect called")
        
        guard let url = message.url,
              let response = MessageHelper.decodeResponseFromURL(url: url) else {
            print("❌ Failed to decode message URL")
            return
        }
        
        print("✅ Decoded response, showing detail view")
        // Always show the detail view when a message is tapped
        showResponseDetailView(for: response)
    }
    
    private func showResponseDetailView(for response: AIResponse) {
        print("📱 showResponseDetailView called")
        
        // Clear main view if it exists
        if let existing = hostingController {
            print("📱 Clearing existing main view controller")
            existing.view.removeFromSuperview()
            existing.removeFromParent()
            hostingController = nil
        }
        
        // Clear old detail view if it exists
        if let existing = detailController {
            print("📱 Clearing existing detail view controller")
            existing.view.removeFromSuperview()
            existing.removeFromParent()
            detailController = nil
        }
        
        print("📱 Creating new detail view")
        
        // Create detail view
        let detailView = ResponseDetailView(response: response, onDismiss: { [weak self] in
            print("📱 Detail view onDismiss called")
            // Clear detail controller
            self?.detailController?.view.removeFromSuperview()
            self?.detailController?.removeFromParent()
            self?.detailController = nil
            
            // Recreate the main view
            print("📱 Recreating main view after dismiss")
            self?.setupView()
        })
        
        let controller = UIHostingController(rootView: AnyView(detailView))
        controller.view.backgroundColor = .white
        
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        
        // Track the detail controller
        self.detailController = controller
        print("📱 Detail controller set and displayed")
    }
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // If we want to stay expanded, block any compact transition
        if shouldStayExpanded && presentationStyle == .compact {
            // Don't call super - this prevents the transition
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
            onSend: { [weak self] response in
                self?.sendMessage(response: response)
            },
            onQuerySubmitted: { [weak self] in
                // Mark that we want to stay expanded when query is submitted
                self?.shouldStayExpanded = true
                self?.requestPresentationStyle(.expanded)
            },
            onResponseReceived: { [weak self] in
                // Keep staying expanded after response
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
    
    private func sendMessage(response: AIResponse) {
        guard let conversation = activeConversation else { return }
        
        // First, send the rich message card
        let richMessage = MessageHelper.createMessage(response: response, conversation: conversation)
        
        conversation.insert(richMessage) { error in
            if let error = error {
                print("❌ Error inserting rich message: \(error)")
            } else {
                print("✅ Rich message card sent successfully")
                
                // Then, send the plain text message
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
        
        // Now we can allow collapsing
        self.shouldStayExpanded = false
        self.requestPresentationStyle(.compact)
    }
}

// MARK: - Main View (Single Unified View)

struct MainView: View {
    @State private var question: String = ""
    @State private var selectedModel: AIModel = .claude
    @State private var response: AIResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingDetail = false
    @State private var detailResponse: AIResponse?
    @FocusState private var isInputFocused: Bool
    
    let onSend: (AIResponse) -> Void
    let onQuerySubmitted: () -> Void
    let onResponseReceived: () -> Void
    
    func showDetailView(for response: AIResponse) {
        detailResponse = response
        showingDetail = true
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Simple header
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
                        ModelSelectionView(selectedModel: $selectedModel)
                        
                        // Input Area
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                TextField("Ask a question...", text: $question, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 15))
                                    .lineLimit(1...6)
                                    .focused($isInputFocused)
                                    .onChange(of: isInputFocused) { focused in
                                        if focused {
                                            // Expand view when keyboard appears
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
                                    .stroke(isInputFocused ? AppTheme.modelColor(for: selectedModel) : AppTheme.border, lineWidth: isInputFocused ? 2 : 1)
                            )
                            
                            HStack(spacing: 8) {
                                if isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Thinking...")
                                            .font(.system(size: 13))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: askAI) {
                                    Text("Send")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(question.isEmpty || isLoading ? AppTheme.textSecondary.opacity(0.3) : AppTheme.modelColor(for: selectedModel))
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
                        
                        // Response Card - scrollable
                        if let response = response {
                            SimpleResponseCard(
                                response: response,
                                availableHeight: geometry.size.height - 350,
                                onSend: {
                                    onSend(response)
                                    self.response = nil
                                },
                                onViewFull: {
                                    showDetailView(for: response)
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
    
    private func askAI() {
        isLoading = true
        errorMessage = nil
        
        // Just dismiss keyboard - view is already expanded from when keyboard appeared
        isInputFocused = false
        
        Task {
            do {
                let result = try await APIService.askAI(
                    question: question,
                    model: selectedModel,
                    userId: UIDevice.current.identifierForVendor?.uuidString
                )
                
                await MainActor.run {
                    self.response = result
                    self.isLoading = false
                    self.question = ""
                    // Keep staying expanded after response
                    onResponseReceived()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Couldn't get a response. Please try again."
                    self.isLoading = false
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
    
    // Calculate responsive height based on available space
    private var cardHeight: CGFloat {
        min(max(availableHeight * 0.6, 150), 400)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
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
            
            // Scrollable Response Text with Markdown
            ScrollView(.vertical, showsIndicators: true) {
                MarkdownText(response.text, fontSize: 14, lineSpacing: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .frame(height: cardHeight)
            
            // Action buttons
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Copy button
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
                    
                    // View full button - show if there are citations
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
                
                // Send button
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
