import SwiftUI

// MARK: - Input Field State

enum InputFieldState {
    case normal
    case focused
    case error(String?)
    case disabled
    case success
    
    var borderColor: Color {
        switch self {
        case .normal, .disabled:
            return .moaiBorder
        case .focused:
            return .securityGreen
        case .error:
            return .moaiError
        case .success:
            return .moaiSuccess
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .focused:
            return 2
        default:
            return 1
        }
    }
}

// MARK: - Moaiy TextField

struct MoaiyTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let state: InputFieldState
    let leadingIcon: String?
    let trailingContent: AnyView?
    
    @FocusState private var isFocused: Bool
    
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        state: InputFieldState = .normal,
        leadingIcon: String? = nil,
        @ViewBuilder trailingContent: () -> some View = { EmptyView() }
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.state = state
        self.leadingIcon = leadingIcon
        self.trailingContent = AnyView(trailingContent())
    }
    
    private var currentState: InputFieldState {
        if case .disabled = state { return .disabled }
        if isFocused { return .focused }
        return state
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.moaiTextPrimary)
            
            // TextField Container
            HStack(spacing: 12) {
                // Leading Icon
                if let leadingIcon = leadingIcon {
                    Image(systemName: leadingIcon)
                        .foregroundStyle(.moaiTextTertiary)
                        .frame(width: 20)
                }
                
                // TextField
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.moaiTextPrimary)
                    .focused($isFocused)
                    .disabled {
                        if case .disabled = state { return true }
                        return false
                    }
                
                // Trailing Content
                trailingContent
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.moaiSurface)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(currentState.borderColor, lineWidth: currentState.borderWidth)
            )
            .opacity {
                if case .disabled = state { return 0.6 }
                return 1
            }
            
            // Error Message
            if case .error(let message) = state, let message = message {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.moaiError)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.moaiError)
                }
            }
            
            // Success Message
            if case .success = state {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.moaiSuccess)
                    Text("Looks good!")
                        .font(.caption)
                        .foregroundStyle(.moaiSuccess)
                }
            }
        }
    }
}

// MARK: - Moaiy SecureField

struct MoaiySecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let state: InputFieldState
    
    @State private var showPassword = false
    @FocusState private var isFocused: Bool
    
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        state: InputFieldState = .normal
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.state = state
    }
    
    private var currentState: InputFieldState {
        if case .disabled = state { return .disabled }
        if isFocused { return .focused }
        return state
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.moaiTextPrimary)
            
            // SecureField Container
            HStack(spacing: 12) {
                // Lock Icon
                Image(systemName: "lock.fill")
                    .foregroundStyle(.moaiTextTertiary)
                    .frame(width: 20)
                
                // SecureField or TextField
                if showPassword {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isFocused)
                } else {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isFocused)
                }
                .disabled {
                    if case .disabled = state { return true }
                    return false
                }
                
                // Eye Toggle Button
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.moaiTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.moaiSurface)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(currentState.borderColor, lineWidth: currentState.borderWidth)
            )
            .opacity {
                if case .disabled = state { return 0.6 }
                return 1
            }
            
            // Error Message
            if case .error(let message) = state, let message = message {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.moaiError)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.moaiError)
                }
            }
        }
    }
}

// MARK: - Password Strength Indicator

struct PasswordStrengthIndicator: View {
    let password: String
    
    private var strength: PasswordStrength {
        calculateStrength(password)
    }
    
    private func calculateStrength(_ password: String) -> PasswordStrength {
        let length = password.count
        if length == 0 { return .none }
        if length < 6 { return .weak }
        if length < 10 { return .medium }
        if length < 14 { return .strong }
        return .veryStrong
    }
    
    enum PasswordStrength {
        case none, weak, medium, strong, veryStrong
        
        var color: Color {
            switch self {
            case .none: return .clear
            case .weak: return .moaiError
            case .medium: return .moaiWarning
            case .strong: return .moaiSuccess
            case .veryStrong: return .securityGreenDark
            }
        }
        
        var label: String {
            switch self {
            case .none: return ""
            case .weak: return "Weak"
            case .medium: return "Medium"
            case .strong: return "Strong"
            case .veryStrong: return "Very Strong"
            }
        }
        
        var progress: Double {
            switch self {
            case .none: return 0
            case .weak: return 0.25
            case .medium: return 0.5
            case .strong: return 0.75
            case .veryStrong: return 1.0
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.moaiBorder)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(strength.color)
                        .frame(width: geometry.size.width * strength.progress)
                }
            }
            .frame(height: 4)
            
            // Label
            if strength != .none {
                Text(strength.label)
                    .font(.caption)
                    .foregroundStyle(strength.color)
            }
        }
    }
}

// MARK: - Search Field

struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    
    @FocusState private var isFocused: Bool
    
    init(text: Binding<String>, placeholder: String = "Search...") {
        self._text = text
        self.placeholder = placeholder
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.moaiTextTertiary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.moaiTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.moaiSurface)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.securityGreen : Color.moaiBorder, lineWidth: isFocused ? 2 : 1)
        )
    }
}

// MARK: - Preview

#Preview("Input Fields") {
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {
            // Basic TextField
            GroupBox("Basic TextField") {
                VStack(spacing: 16) {
                    MoaiyTextField("Name", text: .constant(""), placeholder: "Enter your name")
                    MoaiyTextField("Email", text: .constant("alice@example.com"), placeholder: "Enter email", leadingIcon: "envelope.fill")
                }
                .padding()
            }
            
            // TextField States
            GroupBox("TextField States") {
                VStack(spacing: 16) {
                    MoaiyTextField("Normal", text: .constant("Normal state"), state: .normal)
                    MoaiyTextField("Focused", text: .constant("Focused state"), state: .focused)
                    MoaiyTextField("Error", text: .constant("Invalid"), state: .error("This field is required"))
                    MoaiyTextField("Success", text: .constant("Valid"), state: .success)
                    MoaiyTextField("Disabled", text: .constant("Cannot edit"), state: .disabled)
                }
                .padding()
            }
            
            // SecureField
            GroupBox("SecureField") {
                VStack(spacing: 16) {
                    MoaiySecureField("Password", text: .constant(""), placeholder: "Enter password")
                    MoaiySecureField("Password with Error", text: .constant("123"), state: .error("Password too short"))
                }
                .padding()
            }
            
            // Password Strength
            GroupBox("Password Strength Indicator") {
                VStack(spacing: 16) {
                    PasswordStrengthIndicator(password: "")
                    PasswordStrengthIndicator(password: "weak")
                    PasswordStrengthIndicator(password: "medium123")
                    PasswordStrengthIndicator(password: "strongpass123")
                    PasswordStrengthIndicator(password: "verystrongpassword!")
                }
                .padding()
            }
            
            // Search Field
            GroupBox("Search Field") {
                VStack(spacing: 16) {
                    SearchField(text: .constant(""))
                    SearchField(text: .constant("search term"))
                }
                .padding()
            }
        }
        .padding()
    }
    .frame(width: 500, height: 800)
}
