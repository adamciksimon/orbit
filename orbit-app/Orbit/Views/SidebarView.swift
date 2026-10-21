//
//  SidebarView.swift
//  Orbit
//

import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    /// The sidebar logo is always on screen, so it only orbits while hovered:
    /// a constant animation would keep Orbit busy all day.
    @State private var isHoveringLogo = false

    var body: some View {
        @Bindable var model = model

        List(selection: $model.config.selectedProjectId) {
            Section("Projects") {
                ForEach(model.config.projects) { project in
                    Label {
                        Text(project.name)
                    } icon: {
                        ProjectBadge(name: project.name, color: Theme.planetColor(for: project.id))
                    }
                    .tag(Optional(project.id))
                    .contextMenu {
                        Button("Delete Project", role: .destructive) {
                            model.removeProject(id: project.id)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 8) {
                OrbitMark(size: 44, animated: isHoveringLogo)
                    .onHover { isHoveringLogo = $0 }
                Text("Orbit")
                    .font(.title2.weight(.bold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .onDeleteCommand {
            if let id = model.config.selectedProjectId {
                model.removeProject(id: id)
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Add Project", systemImage: "plus") {
                    model.addProject()
                }
                .help("Add project")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                StatusView()
                SupportButton()
            }
            .padding(12)
        }
    }
}

/// A small planet with the project's first letter.
struct ProjectBadge: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name.first.map { String($0).uppercased() } ?? "?")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.space)
            .frame(width: 20, height: 20)
            .background {
                Circle().fill(
                    RadialGradient(
                        colors: [color.mix(with: .white, by: 0.45), color],
                        center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 14
                    )
                )
            }
            .shadow(color: color.opacity(0.5), radius: 4)
    }
}

private struct StatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            proxyStatus
            trustStatus
            sharingStatus
            if let error = model.errorMessage {
                StatusLine(color: .red, text: error)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.07)))
    }

    @ViewBuilder
    private var proxyStatus: some View {
        switch model.proxyStatus {
        case let .running(port):
            StatusLine(color: Theme.aurora, text: "Proxy running on :\(port)")
        case .starting:
            StatusLine(color: Theme.sun, text: "Proxy starting…")
        case .stopped:
            StatusLine(color: .secondary, text: "Proxy stopped")
        case let .failed(message):
            VStack(alignment: .leading, spacing: 4) {
                StatusLine(color: .red, text: message)
                Button("Retry") { model.restartProxy() }
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var sharingStatus: some View {
        @Bindable var model = model

        Divider()
        Toggle("Share on local network", isOn: $model.isSharingOnNetwork)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("Let phones, tablets and other computers on this network open your .local domains.")

        if model.isSharingOnNetwork {
            VStack(alignment: .leading, spacing: 4) {
                if model.sharedAddresses.isEmpty {
                    StatusLine(color: .secondary, text: "Not connected to a network")
                } else {
                    StatusLine(color: Theme.planet, text: "Shared at \(model.sharedAddresses.joined(separator: ", "))")
                }
                ShareLink(item: AppModel.rootCertificateURL) {
                    Text("Share Root Certificate…")
                }
                .controlSize(.small)
                .help("Install this on other devices so they trust Orbit's HTTPS certificates.")
            }
        }
    }

    @ViewBuilder
    private var trustStatus: some View {
        switch model.trustState {
        case .trusted:
            StatusLine(color: Theme.aurora, text: "Local CA trusted")
        case .unknown:
            StatusLine(color: .secondary, text: "Checking certificates…")
        case .installing:
            StatusLine(color: Theme.sun, text: "Waiting for approval…")
        case .untrusted:
            VStack(alignment: .leading, spacing: 4) {
                StatusLine(color: Theme.sun, text: "Local CA not trusted")
                Button("Trust Certificate…") {
                    Task { await model.trustRootCertificate() }
                }
                .controlSize(.small)
            }
        }
    }
}

private struct SupportButton: View {
    var body: some View {
        Link(destination: AppModel.supportURL) {
            Label("Support Orbit on Ko-fi", systemImage: "cup.and.saucer.fill")
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(Theme.sun)
        .pointerStyle(.link)
        .help("Orbit is made by one person. A coffee keeps it going.")
    }
}

private struct StatusLine: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 3)
            Text(text)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .truncationMode(.tail)
                .help(text)
        }
    }
}
