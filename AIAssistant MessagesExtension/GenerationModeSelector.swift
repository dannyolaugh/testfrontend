import SwiftUI

struct GenerationModeSelector: View {
    @Binding var selectedMode: GenerationMode
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(GenerationMode.allCases, id: \.self) { mode in
                ModeButton(
                    mode: mode,
                    isSelected: selectedMode == mode
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                }
            }
        }
        .padding(4)
        .background(AppTheme.backgroundGray)
        .cornerRadius(8)
    }
}

struct ModeButton: View {
    let mode: GenerationMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(mode.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(isSelected ? AppTheme.modeColor(for: mode) : Color.clear)
            .cornerRadius(6)
        }
    }
}
