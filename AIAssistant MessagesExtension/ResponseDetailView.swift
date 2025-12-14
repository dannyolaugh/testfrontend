import SwiftUI

struct ResponseDetailView: View {
    let response: AIResponse
    @Environment(\.dismiss) var dismiss
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Model Badge
                    HStack(spacing: 8) {
                        Text(response.model.icon)
                            .font(.system(size: 16))
                        
                        Text(response.model.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.modelColor(for: response.model))
                        
                        Spacer()
                        
                        if !response.citations.isEmpty {
                            Text("\(response.citations.count) sources")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                    
                    // Response Text with Markdown
                    MarkdownText(response.text, fontSize: 15, lineSpacing: 4)
                        .padding(.horizontal)
                    
                    // Citations
                    if !response.citations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Sources")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .textCase(.uppercase)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ForEach(Array(response.citations.enumerated()), id: \.offset) { index, citation in
                                CitationRow(index: index + 1, citation: citation)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.white)
            .navigationTitle("Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
    }
}

struct CitationRow: View {
    let index: Int
    let citation: Citation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 20, height: 20)
                .background(AppTheme.backgroundGray)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(citation.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(citation.url)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.slackBlue)
                    .lineLimit(1)
                
                if let snippet = citation.snippet {
                    Text(snippet)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(AppTheme.backgroundGray)
        .cornerRadius(6)
        .padding(.horizontal)
    }
}
