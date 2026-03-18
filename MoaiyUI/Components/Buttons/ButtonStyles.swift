import SwiftUI

// MARK: - Button Style Types

enum MoaiyButtonType {
    case primary
    case secondary
    case tertiary
    case destructive
}

enum MoaiyButtonSize {
    case small
    case medium
    case large
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isEnabled ? (configuration.isPressed ? Color.securityGreenDark : (isHovered ? Color.securityGreenDark : Color.securityGreen)) : Color.securityGreenLight)
            .clipShape(.rect(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovered = true
                case .ended:
                    isHovered = false
                }
            }
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? .securityGreen : .securityGreenLight)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? Color.securityGreen : Color.securityGreenLight, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.securityGreen.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovered = true
                case .ended:
                    isHovered = false
                }
            }
    }
}

// MARK: - Tertiary Button Style

struct TertiaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? .moaiTextPrimary : .moaiTextTertiary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.moaiTextPrimary.opacity(0.05) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovered = true
                case .ended:
                    isHovered = false
                }
            }
    }
}

// MARK: - Destructive Button Style

struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isEnabled ? (configuration.isPressed ? Color.moaiErrorDark : (isHovered ? Color.moaiErrorDark : Color.moaiError)) : Color.moaiError.opacity(0.5))
            .clipShape(.rect(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovered = true
                case .ended:
                    isHovered = false
                }
            }
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.moaiTextSecondary)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.moaiTextPrimary.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - View Extension for Easy Application

extension View {
    func moaiyButtonStyle(_ type: MoaiyButtonType) -> some View {
        switch type {
        case .primary:
            return AnyView(self.buttonStyle(PrimaryButtonStyle()))
        case .secondary:
            return AnyView(self.buttonStyle(SecondaryButtonStyle()))
        case .tertiary:
            return AnyView(self.buttonStyle(TertiaryButtonStyle()))
        case .destructive:
            return AnyView(self.buttonStyle(DestructiveButtonStyle()))
        }
    }
}

// MARK: - Convenience Button Views

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    
    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    
    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(SecondaryButtonStyle())
    }
}

struct IconButton: View {
    let systemName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(IconButtonStyle())
    }
}

// MARK: - Preview

#Preview("Button Styles") {
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {
            // Primary Buttons
            GroupBox("Primary Buttons") {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        PrimaryButton("Encrypt", systemImage: "lock.fill") { }
                        PrimaryButton("Encrypt") { }
                    }
                    HStack(spacing: 16) {
                        PrimaryButton("Encrypt") { }
                            .disabled(true)
                    }
                }
                .padding()
            }
            
            // Secondary Buttons
            GroupBox("Secondary Buttons") {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        SecondaryButton("Share Key", systemImage: "square.and.arrow.up") { }
                        SecondaryButton("Share Key") { }
                    }
                    HStack(spacing: 16) {
                        SecondaryButton("Share Key") { }
                            .disabled(true)
                    }
                }
                .padding()
            }
            
            // Tertiary Buttons
            GroupBox("Tertiary Buttons") {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Button("Cancel") { }
                            .moaiyButtonStyle(.tertiary)
                        Button("Learn More") { }
                            .moaiyButtonStyle(.tertiary)
                    }
                }
                .padding()
            }
            
            // Destructive Buttons
            GroupBox("Destructive Buttons") {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Button("Delete Key", systemImage: "trash") { }
                            .moaiyButtonStyle(.destructive)
                        Button("Delete") { }
                            .moaiyButtonStyle(.destructive)
                            .disabled(true)
                    }
                }
                .padding()
            }
            
            // Icon Buttons
            GroupBox("Icon Buttons") {
                HStack(spacing: 16) {
                    IconButton(systemName: "ellipsis") { }
                    IconButton(systemName: "gearshape.fill") { }
                    IconButton(systemName: "questionmark.circle") { }
                }
                .padding()
            }
            
            // Button Group
            GroupBox("Button Group (Common Pattern)") {
                HStack(spacing: 12) {
                    Spacer()
                    Button("Cancel") { }
                        .moaiyButtonStyle(.tertiary)
                    PrimaryButton("Confirm") { }
                }
                .padding()
            }
        }
        .padding()
    }
    .frame(width: 500, height: 700)
}
