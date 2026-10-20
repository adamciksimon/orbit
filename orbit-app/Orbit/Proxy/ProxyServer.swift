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
    private var redirector: HTTPRedirectServer!

    private var routes: [String: UInt16] = [:]
    private var listener: NWListener?
    private var identity: SecIdentity?
    private var pendingIdentity: SecIdentity?
    private var isShared = false
    private var isReplacingListener = false
    private var connections: [ObjectIdentifier: ProxyConnection] = [:]

    init(
        port: UInt16,
        redirectPort: UInt16,
        onStatus: @escaping @Sendable (Status) -> Void,
        onRedirectFailure: @escaping @Sendable (String) -> Void
    ) {
        self.port = port
        self.onStatus = onStatus
        redirector = HTTPRedirectServer(
            port: redirectPort,
            queue: queue,
            isRouted: { [unowned self] host in routes[host] != nil },
            onFailure: onRedirectFailure
        )
    }

    func setRoutes(_ routes: [ProxyRoute]) {
        let portsByDomain = Dictionary(routes.map { ($0.domain, $0.port) }) { _, last in last }
        queue.async {
            self.routes = portsByDomain
        }
    }

    /// Shared, the proxy accepts connections from other devices on the
    /// network; otherwise only from this Mac.
    func setShared(_ shared: Bool) {
        queue.async {
            guard shared != self.isShared else { return }
            self.isShared = shared
            if !shared {
                for connection in self.connections.values where !connection.isFromThisMac {
                    connection.close()
                }
            }
            if let identity = self.identity {
                self.pendingIdentity = identity
                self.replaceListener()
            }
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
            redirector.stop()
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
        self.identity = identity
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
        if !isShared {
            parameters.requiredInterfaceType = .loopback
        }

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
        redirector.start(shared: isShared)
    }

    private func accept(_ client: NWConnection) {
        guard isShared || client.endpoint.isLoopback else {
            client.cancel()
            return
        }
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

extension NWEndpoint {
    /// Whether the endpoint is a loopback address (including IPv4-mapped ones).
    nonisolated var isLoopback: Bool {
        guard case let .hostPort(host, _) = self else { return false }
        switch host {
        case let .ipv4(address):
            return address.isLoopback
        case let .ipv6(address):
            return address.isLoopback || address.asIPv4?.isLoopback == true
        default:
            return false
        }
    }
}
