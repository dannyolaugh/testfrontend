import SwiftUI

struct ImageDetailView: View {
    let imageResponse: ImageResponse
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Model Badge
                    HStack(spacing: 8) {
                        Text(imageResponse.model.icon)
                            .font(.system(size: 16))
                        
                        Text(imageResponse.model.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.imageModelColor(for: imageResponse.model))
                        
                        Spacer()
                        
                        Text("Generated Image")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                    
                    // Image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 16))
                                Text("Save to Photos")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.imageModelColor(for: imageResponse.model))
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            UIPasteboard.general.image = image
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 16))
                                Text("Copy Image")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.imageModelColor(for: imageResponse.model))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.imageModelColor(for: imageResponse.model).opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.imageModelColor(for: imageResponse.model).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .background(Color.white)
            .navigationTitle("Generated Image")
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
