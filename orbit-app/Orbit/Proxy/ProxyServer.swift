//
//  ProxyServer.swift
//  Orbit
//

import Foundation
import Network
@preconcurrency import Security

/// HTTPS reverse proxy that terminates TLS and forwards each request to the
/// local port registered for its host. All state lives on `queue`.
nonisolated final class ProxyServer: @unchecked Sendable {
    enum Status: Equatable, Sendable {
        case stopped
        case starting
        case running(UInt16)
        case failed(String)
    }

    let port: UInt16

    private let queue = DispatchQueue(label: "co.outloud.Orbit.proxy")
    private let onStatus: @Sendable (Status) -> Void

    private var routes: [String: UInt16] = [:]
    private var listener: NWListener?
    private var pendingIdentity: SecIdentity?
    private var isReplacingListener = false
    private var connections: [ObjectIdentifier: ProxyConnection] = [:]

    init(
        port: UInt16,
        onStatus: @escaping @Sendable (Status) -> Void
    ) {
        self.port = port
        self.onStatus = onStatus
    }

    func setRoutes(_ routes: [ProxyRoute]) {
        let portsByDomain = Dictionary(routes.map { ($0.domain, $0.port) }) { _, last in last }
        queue.async {
            self.routes = portsByDomain
        }
    }

    /// Starts listening with `identity`, replacing any running listener.
    /// Open connections keep the certificate they negotiated.
    func start(identity: SecIdentity) {
        queue.async {
            self.pendingIdentity = identity
            self.replaceListener()
        }
    }

    func stop() {
        queue.sync {
            pendingIdentity = nil
            listener?.cancel()
            listener = nil
            for connection in connections.values {
                connection.close()
            }
        }
    }

    private func replaceListener() {
        guard !isReplacingListener else { return }
        guard let current = listener else {
            startPendingListener()
            return
        }

        // Wait for the old socket to close before binding the port again.
        isReplacingListener = true
        listener = nil
        current.stateUpdateHandler = { [weak self] state in
            guard let self, case .cancelled = state else { return }
            isReplacingListener = false
            startPendingListener()
        }
        current.cancel()
    }

    private func startPendingListener() {
        guard let identity = pendingIdentity else { return }
        pendingIdentity = nil
        onStatus(.starting)

        let tls = NWProtocolTLS.Options()
        let security = tls.securityProtocolOptions
        sec_protocol_options_set_local_identity(security, sec_identity_create(identity)!)
        sec_protocol_options_set_min_tls_protocol_version(security, .TLSv12)
        sec_protocol_options_add_tls_application_protocol(security, "http/1.1")

        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true

        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.allowLocalEndpointReuse = true

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            onStatus(.failed(error.localizedDescription))
            return
        }

        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, let listener, listener === self.listener else { return }
            switch state {
            case .ready:
                onStatus(.running(port))
            case let .failed(error), let .waiting(error):
                onStatus(.failed("Could not listen on port \(port): \(error.reason)"))
                listener.cancel()
                self.listener = nil
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] client in
            self?.accept(client)
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    private func accept(_ client: NWConnection) {
        let connection = ProxyConnection(
            client: client,
            queue: queue,
            resolvePort: { [weak self] host in self?.routes[host] },
            onClose: { [weak self] connection in
                self?.connections[ObjectIdentifier(connection)] = nil
            }
        )
        connections[ObjectIdentifier(connection)] = connection
        connection.start()
    }
}
