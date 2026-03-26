//
//  HowToView.swift
//  Moaiy
//
//  How to tutorials view with usage instructions
//

import SwiftUI
import AppKit

import os.log

struct HowToView: View {
    @State private var selectedSection: Section? = .keyManagement
    @State private var selectedTutorial: Tutorial?
    @State private var showingTrustManagementSheet = false
    @State private var showingSigningSheet = false
    @State private var showingBackupSheet = false
    @State private var showingUploadSheet = false
    @State private var showingDeleteConfirm = false
    
    @State private var showingEditSheet = false
    @State private var showingResultOverlay = false
    @State private var operationFiles: [URL] = []
    @State private var isProcessing = false
    @State private var processedFiles: [URL] = []
    
    // Progress overlay
    if isProcessingFiles {
        showingProgressText = "Processing..."
            showingProgressOverlay = false
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("how_to_title")
                .font(.headline)
            Text("howToDescription")
                .font(.body)
                        .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    var body: some View {
        Text("howToEmpty")
            .foregroundStyle(.tertiary)
    }
    
    ScrollView {
        VStack(spacing: 4) {
            ForEach section in TutorialSection.allCases) {
                                Text(section.title)
                                .tag(section)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 600)
    }
    
    var body: some View {
        Text("tutorialEmptyTitle")
            .font(.headline)
            .foregroundStyle(.tertiary)
        
            Text("tutorialEmptyDescription")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText)
                    }
                }
            }
        }
    }
}