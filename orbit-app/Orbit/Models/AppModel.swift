//
//  AppModel.swift
//  Orbit
//

import Foundation
import Observation
@preconcurrency import Security

enum TrustState: Equatable {
    case unknown
    case trusted
    case untrusted
    case installing
}

@Observable
final class AppModel {
    private static let configURL = CertificateAuthority.dataDirectory.appending(path: "projects.bin")
    private static let proxyPort: UInt16 = 443
    private static let redirectPort: UInt16 = 80
    private static let sharingKey = "shareOnLocalNetwork"

    static let supportURL = URL(string: "https://ko-fi.com/simonadamcik")!

    /// The CA certificate to install on other devices so they trust Orbit.
    static let rootCertificateURL = CertificateAuthority.rootCertificateURL

    var config = ProjectsConfig.empty {
        didSet { configDidChange(from: oldValue) }
    }

    private(set) var proxyStatus = ProxyServer.Status.stopped
    private(set) var trustState = TrustState.unknown
    /// The most recent failure worth showing in the sidebar.
    private(set) var errorMessage: String?
    /// Names /etc/hosts points at this Mac.
    private(set) var hostsFileNames: Set<String> = []
    private(set) var isUpdatingHostsFile = false

    /// Whether other devices on the network can open the `.local` domains.
    var isSharingOnNetwork = UserDefaults.standard.bool(forKey: sharingKey) {
        didSet {
            guard isSharingOnNetwork != oldValue else { return }
            UserDefaults.standard.set(isSharingOnNetwork, forKey: Self.sharingKey)
            applyRoutes()
        }
    }
    /// This Mac's IPv4 addresses on the network while sharing.
    private(set) var sharedAddresses: [String] = []

    @ObservationIgnored private var isConfigReady = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var certificateTask: Task<Void, Never>?
    @ObservationIgnored private var certifiedHostnames: [String]?
    @ObservationIgnored private var identity: SecIdentity?

    @ObservationIgnored private let certificateAuthority = CertificateAuthority()
    @ObservationIgnored private lazy var proxy = ProxyServer(
        port: Self.proxyPort,
        redirectPort: Self.redirectPort,
        onStatus: { [weak self] status in
            guard let self else { return }
            Task { @MainActor in self.proxyStatus = status }
        },
        onRedirectFailure: { [weak self] message in
            guard let self else { return }
            Task { @MainActor in self.errorMessage = message }
        }
    )
    @ObservationIgnored private lazy var advertiser = LocalHostnameAdvertiser(
        onSharedAddresses: { [weak self] addresses in
            guard let self else { return }
            Task { @MainActor in self.sharedAddresses = addresses }
        }
    )

    var selectedProject: Project? {
        config.projects.first { $0.id == config.selectedProjectId }
    }

    // MARK: - Lifecycle

    func start() {
        guard !isConfigReady else { return }
        CertificateAuthority.migrateLegacyDataDirectory()
        loadConfig()
        isConfigReady = true
        refreshHostsFile()
        applyRoutes()
        Task { await prepareCertificates() }
    }

    func shutdown() {
        saveTask?.cancel()
        save()
        proxy.stop()
    }

    // MARK: - Projects

    func addProject() {
        let id = (config.projects.map(\.id).max() ?? 0) + 1
        config.projects.append(Project(id: id, name: "Project \(id)", settings: ProjectSettings(proxiedPaths: [])))
        config.selectedProjectId = id
    }

    func removeProject(id: Int) {
        guard let index = config.projects.firstIndex(where: { $0.id == id }) else { return }
        config.projects.remove(at: index)

        if config.selectedProjectId == id {
            let neighbor = config.projects.indices.contains(index) ? index : index - 1
            config.selectedProjectId = config.projects.indices.contains(neighbor) ? config.projects[neighbor].id : nil
        }
    }

    func addProxy(to projectID: Int) {
        guard let index = config.projects.firstIndex(where: { $0.id == projectID }) else { return }
        let proxies = config.projects[index].settings.proxiedPaths
        let id = (proxies.map(\.id).max() ?? 0) + 1
        config.projects[index].settings.proxiedPaths.append(ProxiedPath(id: id, port: 3000, domain: "new.local"))
    }

    func removeProxy(_ proxyID: Int, from projectID: Int) {
        guard let index = config.projects.firstIndex(where: { $0.id == projectID }) else { return }
        config.projects[index].settings.proxiedPaths.removeAll { $0.id == proxyID }
    }

    /// Domains configured more than once; only the last one is routed.
    var duplicateDomains: Set<String> {
        var seen: Set<String> = []
        var duplicates: Set<String> = []
        for proxy in config.projects.flatMap(\.settings.proxiedPaths) {
            let domain = Domain.served(proxy.domain)
            if !seen.insert(domain).inserted {
                duplicates.insert(domain)
            }
        }
        return duplicates
    }

    // MARK: - Name resolution

    /// Whether `domain` resolves to this Mac without further setup.
    func resolvesLocally(_ domain: String) -> Bool {
        Domain.isMulticast(domain) || domain == "localhost" || hostsFileNames.contains(domain)
    }

    func refreshHostsFile() {
        hostsFileNames = HostsFile.loopbackHostnames()
    }

    /// Writes every routed non-`.local` domain into Orbit's /etc/hosts block.
    func updateHostsFile() async {
        guard !isUpdatingHostsFile else { return }
        isUpdatingHostsFile = true
        defer { isUpdatingHostsFile = false }

        let hostnames = config.routes.map(\.domain).filter { !Domain.isMulticast($0) && !$0.contains("*") }
        do {
            try await HostsFile.update(hostnames: hostnames)
            errorMessage = nil
        } catch HostsFile.Failure.cancelledByUser {
            // Leave the button for another try.
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshHostsFile()
    }

    // MARK: - Persistence

    private func loadConfig() {
        do {
            let data = try Data(contentsOf: Self.configURL)
            config = try JSONDecoder().decode(ProjectsConfig.self, from: data)
        } catch {
            config = .empty
            save()
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: CertificateAuthority.dataDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(config).write(to: Self.configURL, options: .atomic)
        } catch {
            errorMessage = "Saving projects failed: \(error.localizedDescription)"
        }
    }

    private func configDidChange(from oldValue: ProjectsConfig) {
        guard isConfigReady, config != oldValue else { return }
        scheduleSave()
        if config.routes != oldValue.routes {
            applyRoutes()
        }
    }

    // MARK: - Proxy

    private func applyRoutes() {
        let routes = config.routes
        proxy.setRoutes(routes)
        proxy.setShared(isSharingOnNetwork)
        advertiser.update(hostnames: Set(routes.map(\.domain).filter(Domain.isMulticast)), shared: isSharingOnNetwork)

        // Reissue the certificate once edits settle if the domain set changed.
        let hostnames = routes.map(\.domain)
        guard certifiedHostnames != nil, hostnames != certifiedHostnames else { return }
        certificateTask?.cancel()
        certificateTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await issueCertificate(for: hostnames)
        }
    }

    private func prepareCertificates() async {
        await issueCertificate(for: config.routes.map(\.domain))

        if await certificateAuthority.isRootTrusted() {
            trustState = .trusted
        } else {
            await trustRootCertificate()
        }
    }

    /// Asks macOS to trust Orbit's CA for this user (password or Touch ID).
    func trustRootCertificate() async {
        guard trustState != .installing else { return }
        trustState = .installing
        errorMessage = nil

        do {
            try await certificateAuthority.installRoot()
        } catch CertificateAuthority.Failure.cancelledByUser {
            // Leave the "Trust Certificate…" button for another try.
        } catch {
            errorMessage = "Trusting the local CA failed: \(error.localizedDescription)"
        }

        trustState = await certificateAuthority.isRootTrusted() ? .trusted : .untrusted
    }

    private func issueCertificate(for hostnames: [String]) async {
        do {
            let identity = try await certificateAuthority.makeIdentity(for: hostnames)
            certifiedHostnames = hostnames
            errorMessage = nil
            self.identity = identity
            proxy.start(identity: identity)
        } catch {
            errorMessage = "Certificate generation failed: \(error.localizedDescription)"
        }
    }

    func restartProxy() {
        if let identity {
            proxy.start(identity: identity)
        } else {
            Task { await issueCertificate(for: config.routes.map(\.domain)) }
        }
    }
}
