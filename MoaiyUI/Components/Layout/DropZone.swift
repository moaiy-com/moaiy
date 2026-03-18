import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drop Zone Component

struct DropZone: View {
    let title: String
    let subtitle: String
    let supportedTypes: String
    let onDrop: ([URL]) -> Void
    
    @State private var isTargeted = false
    @State private var isProcessing = false
    
    init(
        title: String = "Drag files here",
        subtitle: String = "or click to select",
        supportedTypes: String = "Supports: Any file type",
        onDrop: @escaping ([URL]) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.supportedTypes = supportedTypes
        self.onDrop = onDrop
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isTargeted ? Color.securityGreen.opacity(0.15) : Color.moaiSurfaceElevated)
                    .frame(width: 80, height: 80)
                
                Image(systemName: isTargeted ? "checkmark.circle.fill" : "doc.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(isTargeted ? .securityGreen : .moaiTextTertiary)
                    .scaleEffect(isTargeted ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isTargeted)
            }
            
            // Text
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isTargeted ? .securityGreen : .moaiTextPrimary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.moaiTextSecondary)
            }
            
            // Supported Types
            Text(supportedTypes)
                .font(.caption)
                .foregroundStyle(.moaiTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isTargeted ? Color.securityGreen.opacity(0.05) : Color.moaiBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isTargeted ? Color.securityGreen : Color.moaiBorder,
                    style: StrokeStyle(
                        lineWidth: isTargeted ? 2 : 2,
                        dash: isTargeted ? [] : [8, 4]
                    )
                )
        )
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onTapGesture {
            openFilePicker()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                onDrop(urls)
            }
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            let urls = panel.urls
            if !urls.isEmpty {
                onDrop(urls)
            }
        }
    }
}

// MARK: - Compact Drop Zone

struct CompactDropZone: View {
    let onDrop: ([URL]) -> Void
    
    @State private var isTargeted = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isTargeted ? "checkmark.circle.fill" : "plus.circle.dashed")
                .font(.title2)
                .foregroundStyle(isTargeted ? .securityGreen : .moaiTextTertiary)
            
            Text(isTargeted ? "Release to add" : "Drop files or click to add")
                .font(.subheadline)
                .foregroundStyle(isTargeted ? .securityGreen : .moaiTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.securityGreen.opacity(0.1) : Color.moaiSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isTargeted ? Color.securityGreen : Color.moaiBorder,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onTapGesture {
            openFilePicker()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                onDrop(urls)
            }
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            let urls = panel.urls
            if !urls.isEmpty {
                onDrop(urls)
            }
        }
    }
}

// MARK: - Text Drop Zone

struct TextDropZone: View {
    @Binding var text: String
    let placeholder: String
    
    @State private var isTargeted = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text("Content to encrypt")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.moaiTextPrimary)
            
            // Text Area
            TextEditor(text: $text)
                .font(.body)
                .foregroundStyle(.moaiTextPrimary)
                .focused($isFocused)
                .frame(minHeight: 150)
                .padding(12)
                .background(Color.moaiSurface)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? Color.securityGreen : Color.moaiBorder, lineWidth: isFocused ? 2 : 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(.moaiTextTertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
            
            // Hint
            HStack {
                Text("\(text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.moaiTextTertiary)
                
                Spacer()
                
                if !text.isEmpty {
                    Button("Clear") {
                        text = ""
                    }
                    .font(.caption)
                    .foregroundStyle(.moaiInfo)
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - File Drop Zone with Preview

struct FileDropZoneWithPreview: View {
    @State private var files: [DroppedFile] = []
    let onFilesSelected: ([URL]) -> Void
    
    struct DroppedFile: Identifiable {
        let id = UUID()
        let url: URL
        var name: String { url.lastPathComponent }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if files.isEmpty {
                // Empty State
                DropZone(
                    title: "Drop files here",
                    subtitle: "or click to select",
                    supportedTypes: "Supports: Any file type"
                ) { urls in
                    files = urls.map { DroppedFile(url: $0) }
                    onFilesSelected(urls)
                }
            } else {
                // Files Preview
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Text("Selected Files")
                            .font(.headline)
                            .foregroundStyle(.moaiTextPrimary)
                        
                        Spacer()
                        
                        Button {
                            files = []
                        } label: {
                            Text("Clear All")
                                .font(.subheadline)
                        }
                        .buttonStyle(TertiaryButtonStyle())
                    }
                    
                    // File List
                    ForEach(files) { file in
                        FileRow(file: file) {
                            files.removeAll { $0.id == file.id }
                        }
                    }
                    
                    // Add More
                    CompactDropZone { urls in
                        files.append(contentsOf: urls.map { DroppedFile(url: $0) })
                        onFilesSelected(files.map { $0.url })
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
    }
}

struct FileRow: View {
    let file: FileDropZoneWithPreview.DroppedFile
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .foregroundStyle(.moaiInfo)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .foregroundStyle(.moaiTextPrimary)
                    .lineLimit(1)
                
                Text(file.url.path)
                    .font(.caption)
                    .foregroundStyle(.moaiTextTertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.moaiTextTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.moaiBackground)
        .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("Drop Zones") {
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {
            // Basic Drop Zone
            GroupBox("Basic Drop Zone") {
                DropZone(
                    title: "Drop files here",
                    subtitle: "or click to select",
                    supportedTypes: "Supports: Any file type"
                ) { urls in
                    print("Dropped: \(urls)")
                }
                .padding()
            }
            
            // Compact Drop Zone
            GroupBox("Compact Drop Zone") {
                CompactDropZone { urls in
                    print("Dropped: \(urls)")
                }
                .padding()
            }
            
            // Text Drop Zone
            GroupBox("Text Drop Zone") {
                TextDropZone(
                    text: .constant(""),
                    placeholder: "Enter text to encrypt..."
                )
                .padding()
            }
            
            // File Drop Zone with Preview
            GroupBox("File Drop Zone with Preview") {
                FileDropZoneWithPreview { urls in
                    print("Selected: \(urls)")
                }
                .padding()
            }
        }
        .padding()
    }
    .frame(width: 500, height: 1000)
}
