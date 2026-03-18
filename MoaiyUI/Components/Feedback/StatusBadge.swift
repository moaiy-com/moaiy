import SwiftUI

// MARK: - Status Badge Types

enum BadgeType {
    case success
    case warning
    case error
    case info
    
    var backgroundColor: Color {
        switch self {
        case .success: return Color(hex: "9AE6B4")
        case .warning: return Color(hex: "FEEBC8")
        case .error: return Color(hex: "FED7D7")
        case .info: return Color(hex: "BEE3F8")
        }
    }
    
    var textColor: Color {
        switch self {
        case .success: return Color(hex: "276749")
        case .warning: return Color(hex: "C05621")
        case .error: return Color(hex: "C53030")
        case .info: return Color(hex: "2B6CB0")
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// MARK: - Status Badge Component

struct StatusBadge: View {
    let type: BadgeType
    let text: String
    let showIcon: Bool
    
    init(_ text: String, type: BadgeType, showIcon: Bool = true) {
        self.text = text
        self.type = type
        self.showIcon = showIcon
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if showIcon {
                Image(systemName: type.icon)
                    .font(.caption)
            }
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(type.textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(type.backgroundColor)
        .clipShape(.capsule)
    }
}

// MARK: - Key Status Badge

struct KeyStatusBadge: View {
    let status: KeyStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .clipShape(.capsule)
    }
}

// MARK: - Count Badge

struct CountBadge: View {
    let count: Int
    let style: CountBadgeStyle
    
    enum CountBadgeStyle {
        case primary
        case secondary
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .securityGreen
            case .secondary: return .moaiTextTertiary
            }
        }
    }
    
    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(style.backgroundColor)
            .clipShape(.capsule)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Tag Badge

struct TagBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(.rect(cornerRadius: 4))
    }
}

// MARK: - Progress Badge

struct ProgressBadge: View {
    let progress: Double // 0.0 to 1.0
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.moaiBorder)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * min(progress, 1.0))
                }
            }
            .frame(width: 40, height: 4)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.moaiTextSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.moaiSurfaceElevated)
        .clipShape(.capsule)
    }
    
    private var progressColor: Color {
        if progress < 0.3 { return .moaiError }
        if progress < 0.7 { return .moaiWarning }
        return .moaiSuccess
    }
}

// MARK: - Notification Dot

struct NotificationDot: View {
    let size: CGFloat
    
    init(size: CGFloat = 8) {
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(Color.moaiError)
            .frame(width: size, height: size)
    }
}

// MARK: - New Badge

struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.moaiInfo)
            .clipShape(.rect(cornerRadius: 4))
    }
}

// MARK: - Beta Badge

struct BetaBadge: View {
    var body: some View {
        Text("BETA")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.moaiWarning)
            .clipShape(.rect(cornerRadius: 4))
    }
}

// MARK: - Pro Badge

struct ProBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption2)
            Text("PRO")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            LinearGradient(
                colors: [Color(hex: "F6AD55"), Color(hex: "ED8936")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(.capsule)
    }
}

// MARK: - Preview

#Preview("Status Badges") {
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {
            // Status Badges
            GroupBox("Status Badges") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        StatusBadge("Valid", type: .success)
                        StatusBadge("Expiring Soon", type: .warning)
                        StatusBadge("Expired", type: .error)
                        StatusBadge("New", type: .info)
                    }
                    
                    HStack(spacing: 12) {
                        StatusBadge("Success", type: .success, showIcon: false)
                        StatusBadge("Warning", type: .warning, showIcon: false)
                        StatusBadge("Error", type: .error, showIcon: false)
                    }
                }
                .padding()
            }
            
            // Key Status Badges
            GroupBox("Key Status Badges") {
                HStack(spacing: 12) {
                    KeyStatusBadge(status: .valid)
                    KeyStatusBadge(status: .expiringSoon)
                    KeyStatusBadge(status: .expired)
                    KeyStatusBadge(status: .revoked)
                }
                .padding()
            }
            
            // Count Badges
            GroupBox("Count Badges") {
                HStack(spacing: 12) {
                    CountBadge(count: 3, style: .primary)
                    CountBadge(count: 12, style: .secondary)
                    CountBadge(count: 99, style: .primary)
                }
                .padding()
            }
            
            // Tag Badges
            GroupBox("Tag Badges") {
                HStack(spacing: 12) {
                    TagBadge(text: "RSA-4096", color: .securityGreen)
                    TagBadge(text: "ECC", color: .moaiInfo)
                    TagBadge(text: "RSA-2048", color: .moaiWarning)
                }
                .padding()
            }
            
            // Progress Badges
            GroupBox("Progress Badges") {
                VStack(alignment: .leading, spacing: 12) {
                    ProgressBadge(progress: 0.25, label: "25%")
                    ProgressBadge(progress: 0.5, label: "50%")
                    ProgressBadge(progress: 0.85, label: "85%")
                }
                .padding()
            }
            
            // Special Badges
            GroupBox("Special Badges") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        NewBadge()
                        BetaBadge()
                        ProBadge()
                    }
                    
                    HStack(spacing: 16) {
                        // Notification dot usage
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.title)
                            NotificationDot()
                                .offset(x: 4, y: -4)
                        }
                        
                        // With count
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "envelope.fill")
                                .font(.title)
                            CountBadge(count: 5, style: .primary)
                                .scaleEffect(0.8)
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                .padding()
            }
            
            // Usage Examples
            GroupBox("Usage in Context") {
                VStack(alignment: .leading, spacing: 16) {
                    // In a list item
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.securityGreen)
                        Text("Primary Key")
                        Spacer()
                        KeyStatusBadge(status: .valid)
                    }
                    
                    // In a navigation item
                    HStack {
                        Image(systemName: "tray.fill")
                        Text("Notifications")
                        Spacer()
                        CountBadge(count: 3, style: .primary)
                    }
                    
                    // Pro feature indicator
                    HStack {
                        Text("Hardware Key Support")
                        Spacer()
                        ProBadge()
                    }
                }
                .padding()
            }
        }
        .padding()
    }
    .frame(width: 500, height: 800)
}
