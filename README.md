# Moaiy

> **Guard Your Secrets Like Moai**

## Overview

**Moaiy** is a user-friendly, graphical GPG key management tool for macOS, inspired by the Moai statues, symbolizing mystery, security, and longevity.

Making encryption accessible to everyone, not just tech geeks.

**[中文版 (Chinese Version)](./README_CN.md)**

## Core Values

🗿 **Mystery** - Guarding your digital secrets, keeping sensitive information exclusively yours

🔐 **Security** - Military-grade encryption protection, making your data rock-solid

⏳ **Longevity** - Designed for long-term reliability, encrypt once, protect forever

## Target Users

- **Cryptocurrency Users**: Safely store mnemonic phrases and private keys
- **Privacy Advocates**: Encrypt personal files and communications
- **Business Professionals**: Encrypt sensitive documents

## Tech Stack

- **Language**: Swift 6.2
- **UI Framework**: SwiftUI
- **Minimum Support**: macOS 12.0+
- **Encryption**: Built-in GPG (fully self-contained)

## Project Structure

```
moaiy/
├── README.md              # Project documentation (this file)
├── README_CN.md           # Chinese documentation
├── AGENTS.md              # AI Agent development guide
├── doc/                   # Development documentation
│   ├── brand-story.md    # Brand story
│   ├── product-design.md # Product design
│   ├── technical-architecture.md # Technical architecture
│   ├── app-store-compliance.md   # App Store compliance
│   └── extreme-usability-design.md # Usability design
├── Moaiy/                 # Main application code
│   ├── Models/           # Data models
│   ├── ViewModels/       # Business logic
│   ├── Views/            # UI interfaces
│   ├── Services/         # Core services
│   └── Utils/            # Utilities
├── MoaiyTests/           # Unit tests
└── Moaiy.xcodeproj       # Xcode project
```

## Development Documentation

Detailed development documentation is available in the `doc/` directory:

### 📋 [Brand Story](./doc/brand-story.md)
Brand meaning, values, and development roadmap

### 🎨 [Product Design](./doc/product-design.md)
Product requirements, feature planning, business model

### 🏗️ [Technical Architecture](./doc/technical-architecture.md)
Tech stack selection, system architecture, module design

### ✅ [App Store Compliance](./doc/app-store-compliance.md)
Review risk analysis, sandbox restrictions, compliance requirements

### 🚀 [Extreme Usability Design](./doc/extreme-usability-design.md)
Zero-configuration experience, smart defaults, user flow optimization

### 🤖 [AI Agent Guide](./AGENTS.md)
Development guidelines for AI coding agents

## Development Status

**Current Stage**: Product design and feasibility analysis  
**Next Steps**: Market validation, technical validation, prototype development

## Key Features

### Zero Barrier Entry
- Double-click to run, no technical background required
- Fully self-contained, no external dependencies
- Complete first encryption in 5 minutes

### Intelligent Design
- Automatic configuration and smart recommendations
- Intelligent error diagnosis and auto-repair
- Contextual help system

### Professional Security
- Uses strongest encryption algorithms (RSA-4096, AES-256)
- Fully compliant with App Store review requirements
- Hardware key support (Pro version)

## Version Planning

### Free Open Source Version (GitHub)
- ✅ Basic key management
- ✅ Text/file encryption and decryption
- ✅ Automatic backup
- ❌ Hardware key management

### Pro Paid Version (App Store)
- ✅ All free version features
- ⭐ Hardware key management (YubiKey/CanoKey)
- ⭐ iCloud sync
- ⭐ Automation scripts
- ⭐ Priority technical support

## Internationalization

- **UI Language**: English + Chinese (Simplified)
- **Documentation**: English + Chinese (Simplified)
- **Code & Comments**: English only
- **Localization**: Using SwiftUI's built-in localization system

## Contact

- **Project Name**: Moaiy
- **Official Website**: https://moaiy.com
- **GitHub Repository**: Coming soon
- **License**: TBD (considering GPLv3 or MIT)

> 💡 **Note**: moaiy.com domain is registered, website development is planned

---

*"Guard Your Secrets Like Moai"*

*Last Updated: 2026-03-10*
