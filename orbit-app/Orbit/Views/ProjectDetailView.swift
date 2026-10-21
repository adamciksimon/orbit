//
//  ProjectDetailView.swift
//  Orbit
//

import SwiftUI

struct ProjectDetailView: View {
    @Environment(AppModel.self) private var model
    let projectID: Int

    @State private var isConfirmingDelete = false

    var body: some View {
        if let project = projectBinding {
            Form {
                Section {
                    TextField("Name", text: project.name, prompt: Text("Project name"))
                        .labelsHidden()
                        .font(.title.weight(.bold))
                        .textFieldStyle(.plain)
                }

                Section {
                    if project.wrappedValue.settings.proxiedPaths.isEmpty {
                        VStack(spacing: 10) {
                            OrbitMark(size: 56)
                            Text("No proxies yet. Add one to route a domain to your local server.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(project.settings.proxiedPaths) { proxy in
                            ProxyRow(proxy: proxy, isDuplicate: model.duplicateDomains.contains(Domain.served(proxy.wrappedValue.domain))) {
                                model.removeProxy(proxy.wrappedValue.id, from: projectID)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Proxies")
                        Spacer()
                        Button("Add Proxy", systemImage: "plus") {
                            model.addProxy(to: projectID)
                        }
                        .controlSize(.small)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle(project.wrappedValue.name)
            .toolbar {
                ToolbarItem {
                    Button("Delete Project", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                    .help("Delete project")
                }
            }
            .confirmationDialog("Delete “\(project.wrappedValue.name)”?", isPresented: $isConfirmingDelete) {
                Button("Delete Project", role: .destructive) {
                    model.removeProject(id: projectID)
                }
            } message: {
                Text("Its proxies stop routing immediately.")
            }
        }
    }

    private var projectBinding: Binding<Project>? {
        @Bindable var model = model
        guard let index = model.config.projects.firstIndex(where: { $0.id == projectID }) else {
            return nil
        }
        return $model.config.projects[index]
    }
}

private struct ProxyRow: View {
    @Environment(AppModel.self) private var model
    @Binding var proxy: ProxiedPath
    let isDuplicate: Bool
    let onRemove: () -> Void

    private var domain: String { Domain.served(proxy.domain) }
    private var isValidDomain: Bool { Domain.isValid(domain) }
    private var isValidPort: Bool { (1...65535).contains(proxy.port) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Domain", text: $proxy.domain, prompt: Text("app.example.com"))
                        .spaceField(isInvalid: !isValidDomain)
                    TextField("Port", value: $proxy.port, format: .number.grouping(.never), prompt: Text("3000"))
                        .spaceField(isInvalid: !isValidPort)
                        .frame(width: 88)
                }
                .labelsHidden()

                HStack(spacing: 6) {
                    if isValidDomain, model.resolvesLocally(domain), let url = URL(string: "https://\(domain)") {
                        Link(url.absoluteString, destination: url)
                            .foregroundStyle(Theme.aurora)
                            .pointerStyle(.link)
                    } else {
                        Text("https://\(domain)")
                    }
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.tertiary)
                    Text(verbatim: "http://localhost:\(proxy.port)")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)

                if let warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if !model.resolvesLocally(domain) {
                    HStack(spacing: 8) {
                        Text("\(domain) doesn’t point to this Mac yet. Use a .local domain, or add it to /etc/hosts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Add to /etc/hosts…") {
                            Task { await model.updateHostsFile() }
                        }
                        .controlSize(.small)
                        .disabled(model.isUpdatingHostsFile)
                    }
                }
            }

            Button("Remove Proxy", systemImage: "minus.circle", role: .destructive, action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Remove proxy")
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private var warning: String? {
        if !isValidDomain {
            return "Not a valid hostname; this proxy is inactive."
        }
        if !isValidPort {
            return "Port must be between 1 and 65535; this proxy is inactive."
        }
        if isDuplicate {
            return "This domain is configured more than once; the last entry wins."
        }
        return nil
    }
}
