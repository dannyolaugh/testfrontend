import SwiftUI

struct ImageModelSelectionView: View {
    @Binding var selectedModel: ImageModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Image Model")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ImageModel.allCases, id: \.self) { model in
                        ImageModelChip(
                            model: model,
                            isSelected: selectedModel == model
                        ) {
                            selectedModel = model
                        }
                    }
                }
            }
        }
    }
}

struct ImageModelChip: View {
    let model: ImageModel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(model.icon)
                    .font(.system(size: 14))
                
                Text(model.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.imageModelColor(for: model) : AppTheme.backgroundGray)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.clear : AppTheme.border, lineWidth: 1)
            )
        }
    }
}
