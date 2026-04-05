# Moaiy Design System

> Figma Design Specification Document

## Overview

This document defines the complete design system for Moaiy, a macOS-native GPG key management tool. Use this as a reference when creating Figma designs or implementing UI components.

---

## 1. Brand Identity

### Brand Essence
- **Mystery** - Guarding digital secrets
- **Security** - Military-grade protection
- **Longevity** - Permanent reliability

### Visual Metaphor
Moai statues - solid, mysterious, eternal guardians

---

## 2. Color System

### Primary Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Moai Stone | `#4A5568` | 74, 85, 104 | Primary brand color, headers, icons |
| Moai Dark | `#2D3748` | 45, 55, 72 | Text, emphasis |
| Moai Light | `#718096` | 113, 128, 150 | Secondary text, disabled states |

### Accent Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Security Green | `#48BB78` | 72, 187, 120 | Success, encryption, secure states |
| Security Green Dark | `#38A169` | 56, 161, 105 | Hover states, pressed |
| Security Green Light | `#9AE6B4` | 154, 230, 180 | Backgrounds, highlights |

### Semantic Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Success | `#48BB78` | 72, 187, 120 | Success messages, valid states |
| Warning | `#F6AD55` | 246, 173, 85 | Warnings, attention needed |
| Error | `#FC8181` | 252, 129, 129 | Errors, dangerous actions |
| Error Dark | `#E53E3E` | 229, 62, 62 | Error hover, destructive |
| Info | `#4299E1` | 66, 153, 225 | Information, tips |

### Neutral Colors (Light Mode)

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Background | `#F7FAFC` | 247, 250, 252 | Main background |
| Surface | `#FFFFFF` | 255, 255, 255 | Cards, panels |
| Surface Elevated | `#EDF2F7` | 237, 242, 247 | Elevated surfaces |
| Border | `#E2E8F0` | 226, 232, 240 | Dividers, borders |
| Border Dark | `#CBD5E0` | 203, 213, 224 | Focus borders |
| Text Primary | `#1A202C` | 26, 32, 44 | Primary text |
| Text Secondary | `#4A5568` | 74, 85, 104 | Secondary text |
| Text Tertiary | `#718096` | 113, 128, 150 | Tertiary text, hints |
| Text Disabled | `#A0AEC0` | 160, 174, 192 | Disabled text |

### Neutral Colors (Dark Mode)

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| Background | `#1A202C` | 26, 32, 44 | Main background |
| Surface | `#2D3748` | 45, 55, 72 | Cards, panels |
| Surface Elevated | `#4A5568` | 74, 85, 104 | Elevated surfaces |
| Border | `#4A5568` | 74, 85, 104 | Dividers, borders |
| Border Light | `#718096` | 113, 128, 150 | Focus borders |
| Text Primary | `#F7FAFC` | 247, 250, 252 | Primary text |
| Text Secondary | `#E2E8F0` | 226, 232, 240 | Secondary text |
| Text Tertiary | `#A0AEC0` | 160, 174, 192 | Tertiary text, hints |
| Text Disabled | `#718096` | 113, 128, 150 | Disabled text |

---

## 3. Typography

### Font Family
**SF Pro** (Apple system font - automatically used by SwiftUI)

### Font Scale

| Name | Size | Weight | Line Height | Letter Spacing | Usage |
|------|------|--------|-------------|----------------|-------|
| Display | 34pt | Semibold (600) | 41pt | -0.4px | Large titles, onboarding |
| Title 1 | 28pt | Semibold (600) | 34pt | 0.36px | Screen titles |
| Title 2 | 22pt | Semibold (600) | 28pt | 0.35px | Section headers |
| Title 3 | 20pt | Semibold (600) | 25pt | 0.38px | Card titles |
| Headline | 17pt | Semibold (600) | 22pt | -0.41px | Emphasized text |
| Body | 17pt | Regular (400) | 22pt | -0.41px | Primary content |
| Callout | 16pt | Regular (400) | 21pt | -0.32px | Secondary content |
| Subheadline | 15pt | Regular (400) | 20pt | -0.24px | Captions, hints |
| Footnote | 13pt | Regular (400) | 18pt | -0.08px | Footnotes, metadata |
| Caption 1 | 12pt | Regular (400) | 16pt | 0px | Small labels |
| Caption 2 | 11pt | Regular (400) | 13pt | 0.07px | Tiny text |

### Text Colors

```swift
// SwiftUI semantic colors
.primary        // Primary text (adapts to dark mode)
.secondary      // Secondary text
.tertiary       // Tertiary text
```

---

## 4. Spacing System

### Base Unit: 4px

| Name | Value | Usage |
|------|-------|-------|
| Space 1 | 4px | Tight spacing, inline elements |
| Space 2 | 8px | Compact spacing, icon gaps |
| Space 3 | 12px | Small gaps, list items |
| Space 4 | 16px | Standard padding, card gaps |
| Space 5 | 20px | Section gaps |
| Space 6 | 24px | Large gaps |
| Space 8 | 32px | Extra large gaps |
| Space 10 | 40px | Section separators |
| Space 12 | 48px | Major section separators |

### Layout Margins

| Context | Value |
|---------|-------|
| Window padding | 20px |
| Sidebar width | 220px |
| Content max width | 900px |
| Card padding | 16px |
| List item height | 44px (minimum touch target) |

---

## 5. Border Radius

| Name | Value | Usage |
|------|-------|-------|
| Small | 4px | Buttons, tags, small elements |
| Medium | 8px | Cards, inputs, panels |
| Large | 12px | Large cards, modals |
| XLarge | 16px | Feature cards, hero sections |
| Full | 9999px | Pills, avatars, circular elements |

### SwiftUI Implementation

```swift
.clipShape(.rect(cornerRadius: 8))
```

---

## 6. Shadows & Elevation

### Light Mode

| Level | Shadow | Usage |
|-------|--------|-------|
| 0 | None | Flat surfaces |
| 1 | `0 1px 3px rgba(0,0,0,0.08)` | Cards, list items |
| 2 | `0 4px 6px rgba(0,0,0,0.1)` | Elevated cards, dropdowns |
| 3 | `0 10px 20px rgba(0,0,0,0.12)` | Modals, popovers |
| 4 | `0 20px 40px rgba(0,0,0,0.16)` | Overlays, full-screen modals |

### Dark Mode

| Level | Shadow | Usage |
|-------|--------|-------|
| 0 | None | Flat surfaces |
| 1 | `0 1px 3px rgba(0,0,0,0.3)` | Cards, list items |
| 2 | `0 4px 6px rgba(0,0,0,0.4)` | Elevated cards, dropdowns |
| 3 | `0 10px 20px rgba(0,0,0,0.5)` | Modals, popovers |
| 4 | `0 20px 40px rgba(0,0,0,0.6)` | Overlays, full-screen modals |

---

## 7. Components

### 7.1 Buttons

#### Primary Button
```
Background: Security Green (#48BB78)
Text: White (#FFFFFF)
Border Radius: 8px
Padding: 10px 20px
Min Height: 36px
Font: Headline (17pt Semibold)

States:
- Normal: Background #48BB78
- Hover: Background #38A169
- Pressed: Background #2F855A
- Disabled: Background #9AE6B4, Text #FFFFFF at 50% opacity
```

#### Secondary Button
```
Background: Transparent
Border: 1px solid #48BB78
Text: Security Green (#48BB78)
Border Radius: 8px
Padding: 10px 20px
Min Height: 36px

States:
- Normal: Border #48BB78, Text #48BB78
- Hover: Background rgba(72, 187, 120, 0.1)
- Pressed: Background rgba(72, 187, 120, 0.2)
- Disabled: Border #9AE6B4, Text #9AE6B4
```

#### Tertiary Button
```
Background: Transparent
Text: Primary text color
Border Radius: 8px
Padding: 10px 20px
Min Height: 36px

States:
- Normal: Text primary
- Hover: Background rgba(0,0,0,0.05) light / rgba(255,255,255,0.05) dark
- Pressed: Background rgba(0,0,0,0.1) light / rgba(255,255,255,0.1) dark
```

#### Destructive Button
```
Background: Error (#FC8181)
Text: White (#FFFFFF)

States:
- Normal: Background #FC8181
- Hover: Background #E53E3E
- Pressed: Background #C53030
```

### 7.2 Input Fields

#### Text Field
```
Background: Surface (#FFFFFF / #2D3748)
Border: 1px solid Border (#E2E8F0 / #4A5568)
Border Radius: 8px
Padding: 10px 14px
Min Height: 36px
Font: Body (17pt Regular)
Placeholder Color: Text Tertiary

States:
- Normal: Border #E2E8F0
- Focus: Border #48BB78, 2px width
- Error: Border #FC8181
- Disabled: Background #EDF2F7, Text #A0AEC0
```

#### Secure Field (Password)
```
Same as Text Field, with:
- Eye icon toggle for show/hide
- Password strength indicator below
```

### 7.3 Cards

#### Standard Card
```
Background: Surface (#FFFFFF / #2D3748)
Border: None
Border Radius: 12px
Shadow: Level 1
Padding: 16px

Structure:
┌─────────────────────────────────┐
│  [Icon]  Title              [>] │  ← Header (optional)
│          Subtitle               │
├─────────────────────────────────┤
│  Content area                   │  ← Body
│                                 │
├─────────────────────────────────┤
│  [Button] [Button]              │  ← Footer (optional)
└─────────────────────────────────┘
```

#### Interactive Card (Clickable)
```
Same as Standard Card, with:
- Hover: Shadow Level 2, slight scale (1.01)
- Cursor: Pointer
```

### 7.4 Key Card (Special Component)

```
┌─────────────────────────────────────────────────┐
│  🔐 Primary Key                           [⋯]   │
│  ─────────────────────────────────────────────  │
│  👤 Alice (alice@example.com)                   │
│  📅 Jan 1, 2024 · RSA-4096                      │
│  ─────────────────────────────────────────────  │
│  Status: ✅ Valid · Active use                  │
│  ─────────────────────────────────────────────  │
│  [🔒 Encrypt] [📤 Share Public Key] [💾 Backup] │
└─────────────────────────────────────────────────┘

Specifications:
- Background: Surface
- Border: 1px solid Border
- Border Radius: 12px
- Padding: 16px
- Header: Headline + Tertiary text
- Body: Body + Secondary text
- Actions: Secondary buttons
```

### 7.5 Drop Zone

```
┌─────────────────────────────────────────────────┐
│                                                 │
│                                                 │
│        📄                                       │
│     Drag files here                              │
│     or click to select files                     │
│                                                 │
│     Supports: any file type                      │
│                                                 │
│                                                 │
└─────────────────────────────────────────────────┘

Specifications:
- Background: Background (#F7FAFC / #1A202C)
- Border: 2px dashed Border (#E2E8F0 / #4A5568)
- Border Radius: 16px
- Min Height: 200px

States:
- Normal: Dashed border, default colors
- Hover (file dragged): Border #48BB78, Background rgba(72, 187, 120, 0.05)
- Active: Border #48BB78 solid, Scale 1.02
```

### 7.6 Progress Indicators

#### Linear Progress
```
┌─────────────────────────────────────────────────┐
│  Encrypting...                                   │
│  [████████████░░░░░░░░░░░░] 45%                │
└─────────────────────────────────────────────────┘

Track: Background (#EDF2F7 / #4A5568)
Fill: Security Green (#48BB78)
Height: 4px
Border Radius: 2px
```

#### Circular Progress
```
Diameter: 32px (small), 48px (medium), 64px (large)
Stroke Width: 3px
Color: Security Green
Animation: Rotate indefinitely
```

### 7.7 Status Badges

```
Success:  ✅ Valid           Background: #9AE6B4, Text: #276749
Warning:  ⚠️ Expiring Soon  Background: #FEEBC8, Text: #C05621
Error:    ❌ Expired         Background: #FED7D7, Text: #C53030
Info:     ℹ️ New Key         Background: #BEE3F8, Text: #2B6CB0

Border Radius: Full (pill shape)
Padding: 4px 10px
Font: Caption 1 (12pt Medium)
```

### 7.8 Alerts & Notifications

#### Success Alert
```
┌─────────────────────────────────────────────────┐
│  ✅ Encryption Complete                          │
│  ─────────────────────────────────────────────  │
│  File successfully encrypted and saved to:       │
│  ~/Documents/Encrypted/secret.txt.gpg            │
│                                                 │
│  [Open Folder] [Done]                            │
└─────────────────────────────────────────────────┘

Background: #F0FFF4
Border: 1px solid #9AE6B4
Icon: ✅ in #48BB78
```

#### Error Alert
```
┌─────────────────────────────────────────────────┐
│  ❌ Decryption Failed                             │
│  ─────────────────────────────────────────────  │
│  Analysis:                                       │
│  This file was encrypted for a different key     │
│                                                 │
│  Suggested actions:                              │
│  • Check whether you have the matching key       │
│  • Contact the sender                            │
│                                                 │
│  [Check My Keys] [Contact Support]               │
└─────────────────────────────────────────────────┘

Background: #FFF5F5
Border: 1px solid #FED7D7
Icon: ❌ in #FC8181
```

### 7.9 Tooltips

```
┌────────────────────────┐
│  Tooltip text example    │
│  ▼                     │
└────────────────────────┘

Background: Moai Dark (#2D3748)
Text: White (#FFFFFF)
Border Radius: 6px
Padding: 8px 12px
Font: Subheadline (15pt Regular)
Max Width: 250px
Shadow: Level 2
```

### 7.10 Modal Dialogs

```
┌─────────────────────────────────────────────────┐
│  🔐 Password Required                     [×]   │
├─────────────────────────────────────────────────┤
│                                                 │
│  Enter your key passphrase to continue:          │
│                                                 │
│  Passphrase: [••••••••••••] [👁]                │
│                                                 │
│  ☐ Remember passphrase (5 minutes)               │
│                                                 │
│  💡 This is the passphrase set during key setup  │
│                                                 │
├─────────────────────────────────────────────────┤
│                    [Cancel] [Confirm]            │
└─────────────────────────────────────────────────┘

Width: 440px
Background: Surface
Shadow: Level 4
Border Radius: 12px
Header: Title 3
Footer: Buttons right-aligned
```

---

## 8. Icons

### Icon Set
Use **SF Symbols** for all icons (Apple's official icon library)

### Custom Icons Needed
| Icon | Description | Usage |
|------|-------------|-------|
| Moai Logo | Simplified Moai statue silhouette | App icon, splash |
| Key Shield | Key inside shield | Security indicators |
| Encrypt Arrow | Arrow going into lock | Encrypt actions |
| Decrypt Arrow | Arrow coming out of lock | Decrypt actions |

### Icon Sizes
| Size | Usage |
|------|-------|
| 16px | Inline icons, small badges |
| 20px | Toolbar icons, list icons |
| 24px | Navigation icons |
| 32px | Feature icons |
| 48px | Empty states |
| 64px | Onboarding illustrations |

### Icon Colors
- Default: Text Secondary color
- Active/Selected: Security Green
- Disabled: Text Disabled color
- Destructive: Error color

---

## 9. Motion & Animation

### Timing
| Type | Duration | Easing |
|------|----------|--------|
| Micro (button press) | 100ms | ease-out |
| Small (tooltip) | 200ms | ease-in-out |
| Medium (card hover) | 300ms | ease-in-out |
| Large (modal open) | 400ms | ease-out |
| Page transition | 500ms | ease-in-out |

### Animation Types
1. **Fade** - Opacity transitions
2. **Scale** - Subtle zoom effects (1.0 → 1.02 max)
3. **Slide** - Vertical/horizontal movement
4. **Spring** - Natural bouncing effect for playful elements

### SwiftUI Animation Examples

```swift
// Button press
.animation(.easeOut(duration: 0.1), value: isPressed)

// Card hover
.animation(.easeInOut(duration: 0.3), value: isHovered)

// Modal presentation
.transition(.opacity.combined(with: .scale(scale: 0.95)))
.animation(.spring(response: 0.4), value: isPresented)
```

---

## 10. Dark Mode

### Automatic Support
SwiftUI automatically adapts semantic colors. Use `.colorScheme` environment for custom adaptations.

### Key Differences
| Element | Light Mode | Dark Mode |
|---------|------------|-----------|
| Background | #F7FAFC | #1A202C |
| Surface | #FFFFFF | #2D3748 |
| Shadows | Lighter | Darker, more visible |
| Borders | Light gray | Dark gray |
| Green accent | Same | Slightly brighter |

### Implementation

```swift
// Use semantic colors
.foregroundStyle(.primary)  // Adapts automatically
.background(.background)    // Uses system background

// Custom dark mode colors
extension Color {
    static let moaiBackground = Color("MoaiBackground")
    static let moaiSurface = Color("MoaiSurface")
}
```

---

## 11. Accessibility

### Color Contrast
- All text meets WCAG 2.1 AA standard (4.5:1 for body text)
- Interactive elements have clear focus states
- Don't rely on color alone to convey information

### Touch Targets
- Minimum clickable area: 44x44px
- Button minimum height: 36px
- List item minimum height: 44px

### Dynamic Type Support
- Support system font scaling
- Test with accessibility sizes (AX1-AX5)

### VoiceOver
- All interactive elements have accessibility labels
- Images have descriptive text
- Logical focus order

---

## 12. Responsive Layout

### Window Sizes
| Size | Width | Layout |
|------|-------|--------|
| Compact | < 600px | Single column, sidebar collapsible |
| Regular | 600-900px | Two column, sidebar visible |
| Large | > 900px | Three column possible, more padding |

### Adaptive Components
- Sidebar: Fixed on large screens, overlay on compact
- Cards: Full width on compact, grid on large
- Navigation: Tabs on compact, sidebar on large

---

## 13. Figma Setup Guide

### File Structure
```
Moaiy Design System
├── 🎨 Foundations
│   ├── Colors
│   ├── Typography
│   ├── Spacing
│   └── Effects
├── 🧩 Components
│   ├── Buttons
│   ├── Inputs
│   ├── Cards
│   ├── Navigation
│   └── Feedback
├── 📱 Screens
│   ├── Key Management
│   ├── Encryption
│   ├── Decryption
│   └── Settings
└── 📐 Templates
    ├── Modal
    ├── Alert
    └── Empty State
```

### Color Styles
Create color styles with naming convention:
- `primary/default`
- `primary/hover`
- `primary/pressed`
- `semantic/success`
- `semantic/error`
- `neutral/background`
- etc.

### Text Styles
Create text styles matching the typography scale:
- `Display`
- `Title 1`, `Title 2`, `Title 3`
- `Headline`
- `Body`
- `Callout`
- `Subheadline`
- `Footnote`
- `Caption 1`, `Caption 2`

### Component Variants
Use Figma's component variants for:
- Button states (default, hover, pressed, disabled)
- Input states (default, focus, error, disabled)
- Theme modes (light, dark)
- Size variants (small, medium, large)

---

## 14. Implementation Notes

### SwiftUI Color Extension

```swift
import SwiftUI

extension Color {
    // Primary
    static let moaiStone = Color(hex: "4A5568")
    static let moaiDark = Color(hex: "2D3748")
    static let moaiLight = Color(hex: "718096")
    
    // Accent
    static let securityGreen = Color(hex: "48BB78")
    static let securityGreenDark = Color(hex: "38A169")
    static let securityGreenLight = Color(hex: "9AE6B4")
    
    // Semantic
    static let success = Color(hex: "48BB78")
    static let warning = Color(hex: "F6AD55")
    static let error = Color(hex: "FC8181")
    static let info = Color(hex: "4299E1")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

### SwiftUI Button Styles

```swift
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.securityGreen)
            .clipShape(.rect(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Usage
Button("Encrypt") { }
    .buttonStyle(PrimaryButtonStyle())
```

---

## 15. Resources

### Design Resources
- [SF Symbols](https://developer.apple.com/sf-symbols/) - Apple's icon library
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [macOS Design Resources](https://developer.apple.com/design/resources/)

### Color Tools
- [Coolors](https://coolors.co/) - Color palette generator
- [Contrast Checker](https://webaim.org/resources/contrastchecker/) - WCAG compliance

### Typography
- [Apple Fonts](https://developer.apple.com/fonts/) - SF Pro download

---

*Last Updated: 2026-03-12*
*Version: 1.0*
