//
//  SettingsView.swift
//  Moaiy
//
//  Application settings view
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("defaultKeyType") private var defaultKeyType = 0
    @State private var gpgVersion: String = ""
    @State private var activeGPGHomePath: String = ""
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var nounProjectMoaiURL: URL? {
        URL(string: "https://thenounproject.com/browse/icons/term/moai-statue/")
    }

    private var privacyPolicyURL: URL? {
        URL(string: "https://moaiy.com/privacy")
    }
    
    var body: some View {
        Form {
            Section {
                Picker("setting_default_key_type", selection: $defaultKeyType) {
                    Text("key_type_rsa4096").tag(0)
                    Text("key_type_rsa2048").tag(1)
                    Text("key_type_ecc_curve25519").tag(2)
                }
            } header: {
                Text("section_general")
                    .font(.headline)
            }

            Section {
                HStack(alignment: .top) {
                    Text("setting_keyring_path")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if activeGPGHomePath.isEmpty {
                        Text("setting_keyring_path_unavailable")
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(activeGPGHomePath)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }

                if !activeGPGHomePath.isEmpty {
                    Button("open_in_finder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: activeGPGHomePath, isDirectory: true))
                    }
                }
            } header: {
                Text("section_keyring")
                    .font(.headline)
            }
            
            Section {
                HStack {
                    Text("about_app_version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(appVersion) (\(appBuild))")
                        .foregroundStyle(.primary)
                }
                
                HStack {
                    Text("about_gpg_version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if gpgVersion.isEmpty {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("\(gpgVersion) · \(String(localized: "about_gpg_embedded"))")
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                HStack {
                    Text("setting_keyring_mode")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("setting_keyring_mode_app")
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("about_icon_credit_title")
                        .foregroundStyle(.secondary)

                    Text("about_icon_credit_text")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let nounProjectMoaiURL {
                        Link(destination: nounProjectMoaiURL) {
                            Text("about_icon_credit_link")
                        }
                        .font(.caption)
                    }
                }

                if let privacyPolicyURL {
                    Link(destination: privacyPolicyURL) {
                        Text("privacy_policy")
                    }
                }
            } header: {
                Text("section_about")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
        .task {
            await loadGPGVersion()
            refreshKeyringState()
        }
    }
    
    @MainActor
    private func loadGPGVersion() async {
        let service = GPGService.shared
        if let version = service.gpgVersion {
            gpgVersion = version
        } else {
            gpgVersion = "about_gpg_not_available"
        }
    }

    @MainActor
    private func refreshKeyringState() {
        let service = GPGService.shared
        activeGPGHomePath = service.activeGPGHomePath
    }
}

#Preview {
    SettingsView()
        .frame(width: 500, height: 500)
}
