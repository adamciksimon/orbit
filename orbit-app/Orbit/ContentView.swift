//
//  ContentView.swift
//  Orbit
//
//  Created by Simon Adamcik on 20/10/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            if let project = model.selectedProject {
                ProjectDetailView(projectID: project.id)
                    .id(project.id)
            } else {
                ContentUnavailableView {
                    VStack(spacing: 16) {
                        OrbitMark(size: 120)
                        Text("No Project Selected")
                    }
                } description: {
                    Text("Select a project from the sidebar, or create one with ⌘N.")
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
