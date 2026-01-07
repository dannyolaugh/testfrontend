import SwiftUI

struct AIInputView: View {
    @Binding var question: String
    @Binding var selectedModel: AIModel
    @State private var isLoading = false
    @State private var response: AIResponse?
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool
    
    let onSend: (AIResponse) -> Void
    let onViewFullResponse: ((AIResponse) -> Void)?
    let onResponseChanged: ((AIResponse?) -> Void)?
    let onStateChanged: ((String, AIModel) -> Void)?
    
    // Initializer with support for initial response
    init(
        question: Binding<String>,
        selectedModel: Binding<AIModel>,
        initialResponse: AIResponse? = nil,
        onSend: @escaping (AIResponse) -> Void,
        onViewFullResponse: ((AIResponse) -> Void)? = nil,
        onResponseChanged: ((AIResponse?) -> Void)? = nil,
        onStateChanged: ((String, AIModel) -> Void)? = nil
    ) {
        self._question = question
        self._selectedModel = selectedModel
        self._response = State(initialValue: initialResponse)
        self.onSend = onSend
        self.onViewFullResponse = onViewFullResponse
        self.onResponseChanged = onResponseChanged
        self.onStateChanged = onStateChanged
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content that should be at top
            VStack(spacing: 16) {
                ModelSelectionView(selectedModel: $selectedModel)
                    .onChange(of: selectedModel) { newValue in
                        onStateChanged?(question, newValue)
                    }
                
                // Input Area
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        TextField("Ask a question...", text: $question, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .lineLimit(1...6)
                            .focused($isInputFocused)
                            .onChange(of: question) { newValue in
                                onStateChanged?(newValue, selectedModel)
                            }
                        
                        if !question.isEmpty {
                            Button(action: {
                                question = ""
                                onStateChanged?("", selectedModel)
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
                
                // Response
                if let response = response {
                    ResponsePreview(
                        response: response,
                        isExpanded: false, // Will be overridden by parent if needed
                        onSend: {
                            onSend(response)
                            self.response = nil
                            onResponseChanged?(nil)
                        },
                        onViewFull: {
                            if let onViewFullResponse = onViewFullResponse {
                                onViewFullResponse(response)
                            }
                        }
                    )
                }
            }
            .padding(16)
            
            Spacer(minLength: 0) // Push everything to top
        }
    }
    
    private func askAI() {
        isLoading = true
        errorMessage = nil
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
                    onResponseChanged?(result)
                    onStateChanged?("", selectedModel)
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

struct ResponsePreview: View {
    let response: AIResponse
    let isExpanded: Bool
    let onSend: () -> Void
    let onViewFull: (() -> Void)?
    
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
            
            // Response text - scrollable when expanded, limited lines when compact
            if isExpanded {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(response.text)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(height: 250) // Fixed height to make scrolling work
                .background(Color.white)
            } else {
                // Compact mode - show limited lines with tap to expand
                Button(action: { onViewFull?() }) {
                    Text(response.text)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineSpacing(3)
                        .lineLimit(8)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(onViewFull == nil)
            }
            
            // Action buttons
            HStack(spacing: 8) {
                // View full button - always show if callback is available
                if let onViewFull = onViewFull {
                    Button(action: onViewFull) {
                        HStack {
                            Image(systemName: "eye")
                                .font(.system(size: 12))
                            Text("View Full")
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
                
                // Send button
                Button(action: onSend) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12))
                        Text("Send to Chat")
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
