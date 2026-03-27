//
//  HowToView.swift
//  Moaiy
//
//  User guide and tutorial view
//

import SwiftUI

struct HowToView: View {
    @State private var selectedItem: TutorialItem?
    @State private var searchText = ""
    
    private let sections = TutorialData.sections
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            HStack {
                                Image(systemName: item.iconName)
                                    .foregroundStyle(.blue)
                                Text(item.title)
                            }
                            .tag(item)
                        }
                    }
                }
            }
            .navigationTitle("how_to_title")
            .searchable(text: $searchText)
        } detail: {
            if let item = selectedItem {
                DetailView(item: item)
            } else {
                EmptyView()
            }
        }
    }
}

struct DetailView: View {
    let item: TutorialItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: item.iconName)
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text(item.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Divider()
                
                Text(item.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(40)
        }
    }
}

struct EmptyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("how_to_select_topic")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HowToView()
}
