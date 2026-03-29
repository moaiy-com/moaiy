//
//  MainView.swift
//  Moaiy
//
//  Main view with sidebar navigation
//

import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationStack {
            KeyManagementView()
        }
    }
}

#Preview {
    MainView()
        .frame(width: 1000, height: 700)
}
