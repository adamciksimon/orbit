//
//  ProjectsConfig.swift
//  Orbit
//

import Foundation

/// Persisted app state. The JSON shape matches the original Tauri app's
/// `~/.orbit/projects.bin`, so existing configs keep working.
nonisolated struct ProjectsConfig: Codable, Equatable, Sendable {
    var selectedProjectId: Int?
    var projects: [Project]

    static let empty = ProjectsConfig(selectedProjectId: nil, projects: [])
}

nonisolated struct Project: Codable, Equatable, Identifiable, Sendable {
    var id: Int
    var name: String
    var settings: ProjectSettings
}

nonisolated struct ProjectSettings: Codable, Equatable, Sendable {
    var proxiedPaths: [ProxiedPath]
}

nonisolated struct ProxiedPath: Codable, Equatable, Identifiable, Sendable {
    var id: Int
    var port: Int
    var domain: String
}

/// A domain that the proxy forwards to `localhost:<port>`.
nonisolated struct ProxyRoute: Equatable, Hashable, Sendable {
    var domain: String
    var port: UInt16
}

nonisolated enum Domain {
    /// Hostname pattern accepted by mkcert.
    private static let hostnamePattern = #/^(\*\.)?[0-9a-z_-]([0-9a-z._-]*[0-9a-z_-])?$/#

    static func normalize(_ domain: String) -> String {
        var normalized = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while normalized.hasSuffix(".") {
            normalized.removeLast()
        }
        return normalized
    }

    /// The hostname Orbit serves for a configured domain. Single-label names
    /// such as `portfolio` can't resolve on their own, so they become
    /// `portfolio.local`, which mDNS resolves without any setup.
    static func served(_ domain: String) -> String {
        let normalized = normalize(domain)
        guard !normalized.isEmpty, !normalized.contains("."), normalized != "localhost" else {
            return normalized
        }
        return normalized + ".local"
    }

    static func isValid(_ normalizedDomain: String) -> Bool {
        normalizedDomain.wholeMatch(of: hostnamePattern) != nil
    }

    /// `.local` names are announced over mDNS; anything else must resolve to
    /// 127.0.0.1 some other way (for example `/etc/hosts`).
    static func isMulticast(_ normalizedDomain: String) -> Bool {
        normalizedDomain.hasSuffix(".local")
    }
}

extension ProjectsConfig {
    /// Routes the proxy should serve. Later entries win when a domain is
    /// configured twice, like the original route sync.
    var routes: [ProxyRoute] {
        var portsByDomain: [String: UInt16] = [:]
        for proxy in projects.flatMap(\.settings.proxiedPaths) {
            let domain = Domain.served(proxy.domain)
            guard Domain.isValid(domain), let port = UInt16(exactly: proxy.port), port > 0 else {
                continue
            }
            portsByDomain[domain] = port
        }
        return portsByDomain
            .map { ProxyRoute(domain: $0.key, port: $0.value) }
            .sorted { $0.domain < $1.domain }
    }
}
