//
//  OrbitApp.swift
//  Orbit
//
//  Created by Simon Adamcik on 20/10/2026.
//

import AppKit
import SwiftUI

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("Orbit", id: "main") {
            ContentView()
                .environment(appDelegate.model)
                .frame(minWidth: 720, minHeight: 480)
                .containerBackground(for: .window) { SpaceBackground() }
                .preferredColorScheme(.dark)
                .fontDesign(.rounded)
        }
        .defaultSize(width: 1000, height: 750)
        .commands {
            CommandGroup(after: .appInfo) {
                Link("Support Orbit on Ko-fi…", destination: AppModel.supportURL)
            }
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    appDelegate.model.addProject()
                }
                .keyboardShortcut("n")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Pick up manual /etc/hosts edits.
        model.refreshHostsFile()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
    }
}
