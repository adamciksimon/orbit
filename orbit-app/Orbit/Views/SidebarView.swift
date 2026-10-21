//
//  SidebarView.swift
//  Orbit
//

import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.config.selectedProjectId) {
            Section("Projects") {
                ForEach(model.config.projects) { project in
                    Label {
                        Text(project.name)
                    } icon: {
                        ProjectBadge(name: project.name)
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
            StatusView()
                .padding(12)
        }
    }
}

/// First-letter tile, like the original sidebar's project buttons.
struct ProjectBadge: View {
    let name: String

    var body: some View {
        Text(name.first.map { String($0).uppercased() } ?? "?")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(.tint, in: RoundedRectangle(cornerRadius: 5))
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
            Divider()
            Link(destination: AppModel.supportURL) {
                Label("Support Orbit on Ko-fi", systemImage: "cup.and.saucer.fill")
            }
            .foregroundStyle(.secondary)
            .help("Orbit is made by one person. A coffee keeps it going.")
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var proxyStatus: some View {
        switch model.proxyStatus {
        case let .running(port):
            StatusLine(color: .green, text: "Proxy running on :\(port)")
        case .starting:
            StatusLine(color: .yellow, text: "Proxy starting…")
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
                    StatusLine(color: .blue, text: "Shared at \(model.sharedAddresses.joined(separator: ", "))")
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
            StatusLine(color: .green, text: "Local CA trusted")
        case .unknown:
            StatusLine(color: .secondary, text: "Checking certificates…")
        case .installing:
            StatusLine(color: .yellow, text: "Waiting for approval…")
        case .untrusted:
            VStack(alignment: .leading, spacing: 4) {
                StatusLine(color: .orange, text: "Local CA not trusted")
                Button("Trust Certificate…") {
                    Task { await model.trustRootCertificate() }
                }
                .controlSize(.small)
            }
        }
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
            Text(text)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .truncationMode(.tail)
                .help(text)
        }
    }
}
