import SwiftUI

// MARK: - Key Status Enum

enum KeyStatus {
    case valid
    case expiringSoon
    case expired
    case revoked
    
    var icon: String {
        switch self {
        case .valid: return "checkmark.circle.fill"
        case .expiringSoon: return "exclamationmark.triangle.fill"
        case .expired: return "xmark.circle.fill"
        case .revoked: return "xmark.octagon.fill"
        }
    }
    
    var label: String {
        switch self {
        case .valid: return "Valid"
        case .expiringSoon: return "Expiring Soon"
        case .expired: return "Expired"
        case .revoked: return "Revoked"
        }
    }
    
    var color: Color {
        switch self {
        case .valid: return .moaiSuccess
        case .expiringSoon: return .moaiWarning
        case .expired, .revoked: return .moaiError
        }
    }
}

// MARK: - Key Model (Sample)

struct Key: Identifiable, Hashable {
    let id: UUID
    let name: String
    let email: String
    let algorithm: String
    let createdAt: Date
    let expiresAt: Date?
    let status: KeyStatus
    
    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        algorithm: String = "RSA-4096",
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        status: KeyStatus = .valid
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.algorithm = algorithm
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.status = status
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
}

// MARK: - Key Card Component

struct KeyCard: View {
    let key: Key
    let onEncrypt: () -> Void
    let onShare: () -> Void
    let onBackup: () -> Void
    let onMore: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundStyle(.securityGreen)
                
                Text(key.name)
                    .font(.headline)
                    .foregroundStyle(.moaiTextPrimary)
                
                Spacer()
                
                Button(action: onMore) {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.moaiTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.moaiTextTertiary)
                    Text(key.email)
                        .font(.subheadline)
                        .foregroundStyle(.moaiTextSecondary)
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.moaiTextTertiary)
                        Text(key.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.moaiTextTertiary)
                    }
                    
                    Text("·")
                        .foregroundStyle(.moaiTextTertiary)
                    
                    Text(key.algorithm)
                        .font(.caption)
                        .foregroundStyle(.moaiTextTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Status
            HStack {
                Image(systemName: key.status.icon)
                    .foregroundStyle(key.status.color)
                Text(key.status.label)
                    .font(.subheadline)
                    .foregroundStyle(key.status.color)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onEncrypt) {
                    Label("Encrypt", systemImage: "lock.fill")
                        .font(.subheadline)
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(TertiaryButtonStyle())
                
                Button(action: onBackup) {
                    Label("Backup", systemImage: "externaldrive.fill")
                        .font(.subheadline)
                }
                .buttonStyle(TertiaryButtonStyle())
            }
            .padding(16)
        }
        .background(Color.moaiSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.moaiBorder, lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(isHovered ? 0.12 : 0.06),
            radius: isHovered ? 8 : 4,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
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

// MARK: - Info Card Component

struct InfoCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        title: String,
        icon: String,
        iconColor: Color = .securityGreen,
        content: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.moaiTextPrimary)
                
                Spacer()
            }
            
            // Content
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.moaiTextSecondary)
                .lineLimit(nil)
            
            // Action Button
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(16)
        .background(Color.moaiSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.moaiBorder, lineWidth: 1)
        )
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.moaiTextSecondary)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.moaiTextPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.moaiSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.moaiBorder, lineWidth: 1)
        )
    }
}

// MARK: - Empty State Card

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.moaiTextTertiary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.moaiTextPrimary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.moaiTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            PrimaryButton(actionTitle, action: action)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.moaiSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.moaiBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Cards") {
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {
            // Key Cards
            GroupBox("Key Cards") {
                VStack(spacing: 16) {
                    KeyCard(
                        key: Key(name: "Primary Key", email: "alice@example.com", status: .valid),
                        onEncrypt: {},
                        onShare: {},
                        onBackup: {},
                        onMore: {}
                    )
                    
                    KeyCard(
                        key: Key(name: "Work Key", email: "alice@work.com", status: .expiringSoon),
                        onEncrypt: {},
                        onShare: {},
                        onBackup: {},
                        onMore: {}
                    )
                    
                    KeyCard(
                        key: Key(name: "Old Key", email: "old@example.com", status: .expired),
                        onEncrypt: {},
                        onShare: {},
                        onBackup: {},
                        onMore: {}
                    )
                }
                .padding()
            }
            
            // Info Cards
            GroupBox("Info Cards") {
                VStack(spacing: 16) {
                    InfoCard(
                        title: "Quick Tip",
                        icon: "lightbulb.fill",
                        iconColor: .moaiWarning,
                        content: "You can encrypt files by simply dragging them to the app window.",
                        actionTitle: "Learn More",
                        action: {}
                    )
                    
                    InfoCard(
                        title: "Security Notice",
                        icon: "shield.checkered",
                        iconColor: .securityGreen,
                        content: "Your keys are stored securely in the macOS Keychain."
                    )
                }
                .padding()
            }
            
            // Stat Cards
            GroupBox("Stat Cards") {
                HStack(spacing: 16) {
                    StatCard(title: "Total Keys", value: "3", icon: "key.fill", color: .securityGreen)
                    StatCard(title: "Encrypted Files", value: "128", icon: "lock.fill", color: .moaiInfo)
                    StatCard(title: "Last Backup", value: "2d", icon: "externaldrive.fill", color: .moaiWarning)
                }
                .padding()
            }
            
            // Empty State
            GroupBox("Empty State") {
                EmptyStateCard(
                    icon: "key.slash",
                    title: "No Keys Yet",
                    description: "Create your first encryption key to start protecting your secrets.",
                    actionTitle: "Create Key",
                    action: {}
                )
                .padding()
            }
        }
        .padding()
    }
    .frame(width: 500, height: 1200)
}
