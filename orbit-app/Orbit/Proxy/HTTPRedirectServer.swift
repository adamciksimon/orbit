//
//  HTTPRedirectServer.swift
//  Orbit
//

import Foundation
import Network

/// Plain HTTP listener on port 80 that sends every request for a routed host
/// to the same URL over HTTPS, so typing `portfolio.local` (which browsers try
/// as `http://` first) lands on the proxy. Runs on `ProxyServer`'s queue.
nonisolated final class HTTPRedirectServer: @unchecked Sendable {
    private static let maxHeadBytes = 16 * 1024

    let port: UInt16

    private let queue: DispatchQueue
    private let isRouted: (String) -> Bool
    private let onFailure: @Sendable (String) -> Void

    private var listener: NWListener?
    private var pendingShared: Bool?
    private var isReplacingListener = false

    init(
        port: UInt16,
        queue: DispatchQueue,
        isRouted: @escaping (String) -> Bool,
        onFailure: @escaping @Sendable (String) -> Void
    ) {
        self.port = port
        self.queue = queue
        self.isRouted = isRouted
        self.onFailure = onFailure
    }

    /// Starts listening, replacing any running listener. Must be called on `queue`.
    func start(shared: Bool) {
        pendingShared = shared
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

    /// Must be called on `queue`.
    func stop() {
        pendingShared = nil
        listener?.cancel()
        listener = nil
    }

    private func startPendingListener() {
        guard let shared = pendingShared else { return }
        pendingShared = nil

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        if !shared {
            parameters.requiredInterfaceType = .loopback
        }

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            onFailure("HTTP redirects are off: \(error.localizedDescription)")
            return
        }

        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, let listener, listener === self.listener else { return }
            switch state {
            case let .failed(error), let .waiting(error):
                onFailure("HTTP redirects are off (port \(port): \(error.reason)). Type https:// in the address bar.")
                listener.cancel()
                self.listener = nil
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] client in
            guard let self else { return }
            guard shared || client.endpoint.isLoopback else {
                client.cancel()
                return
            }
            client.start(queue: queue)
            readHead(from: client, buffer: [])
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    private func readHead(from client: NWConnection, buffer: [UInt8]) {
        client.receive(minimumIncompleteLength: 1, maximumLength: Self.maxHeadBytes) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data {
                buffer += data
            }

            if let end = buffer.firstRange(of: headTerminator) {
                respond(to: HTTPRequestHead(buffer[..<end.lowerBound]), on: client)
            } else if buffer.count > Self.maxHeadBytes || isComplete || error != nil {
                client.cancel()
            } else {
                readHead(from: client, buffer: buffer)
            }
        }
    }

    private func respond(to head: HTTPRequestHead?, on client: NWConnection) {
        let response: [UInt8]
        if let head, let host = head.host, isRouted(host) {
            // Origin-form targets keep their path and query; anything else
            // (absolute-form, `*`) goes to the root.
            let path = head.target.hasPrefix("/") ? head.target : "/"
            let location = "https://\(host)\(path)"
            response = Array((
                "HTTP/1.1 307 Temporary Redirect\r\n"
                    + "Location: \(location)\r\n"
                    + "Content-Length: 0\r\n"
                    + "Connection: close\r\n\r\n"
            ).utf8)
        } else if let host = head?.host {
            response = HTTPResponse.text(404, "Not Found", "Orbit: no active route for host \(host)\n")
        } else {
            response = HTTPResponse.text(400, "Bad Request", "Orbit: malformed request\n")
        }

        client.send(content: response, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            client.cancel()
        })
    }
}
