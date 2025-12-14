import SwiftUI

struct ImageResponseCard: View {
    let imageResponse: ImageResponse
    let image: UIImage?
    let availableHeight: CGFloat
    let onSend: () -> Void
    
    private var cardHeight: CGFloat {
        min(max(availableHeight * 0.6, 300), 500)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text(imageResponse.model.icon)
                        .font(.system(size: 14))
                    
                    Text(imageResponse.model.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.imageModelColor(for: imageResponse.model))
                }
                
                Spacer()
                
                Text("Image")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            // Image Display
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: cardHeight)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(AppTheme.backgroundGray)
                    .frame(height: cardHeight)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                    )
            }
            
            // Prompt
            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .textCase(.uppercase)
                
                Text(imageResponse.prompt)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.backgroundGray)
            .cornerRadius(6)
            
            // Action buttons
            HStack(spacing: 8) {
                // Save button
                if let image = image {
                    Button(action: {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 12))
                            Text("Save")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.imageModelColor(for: imageResponse.model))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.imageModelColor(for: imageResponse.model).opacity(0.1))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppTheme.imageModelColor(for: imageResponse.model).opacity(0.3), lineWidth: 1)
                        )
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
