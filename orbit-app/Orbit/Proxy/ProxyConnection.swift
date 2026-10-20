//
//  ProxyConnection.swift
//  Orbit
//

import Foundation
import Network

/// One TLS client connection. Request heads are parsed so each request's
/// `Host` can be routed and rewritten; bodies and responses are streamed
/// through unchanged. Upgrade requests (WebSockets) switch to a raw tunnel.
nonisolated final class ProxyConnection: @unchecked Sendable {
    private enum Phase {
        case head
        case body(BodyFraming)
        case tunnel
    }

    private static let maxHeadBytes = 64 * 1024
    private static let readSize = 64 * 1024

    private let client: NWConnection
    private let queue: DispatchQueue
    private let resolvePort: (String) -> UInt16?
    private let onClose: (ProxyConnection) -> Void

    private var phase = Phase.head
    private var buffer: [UInt8] = []
    private var upstream: NWConnection?
    private var upstreamPort: UInt16?
    private var upstreamHasResponded = false
    private var isClosed = false

    init(
        client: NWConnection,
        queue: DispatchQueue,
        resolvePort: @escaping (String) -> UInt16?,
        onClose: @escaping (ProxyConnection) -> Void
    ) {
        self.client = client
        self.queue = queue
        self.resolvePort = resolvePort
        self.onClose = onClose
    }

    func start() {
        client.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.close()
            default:
                break
            }
        }
        client.start(queue: queue)
        readClient()
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        client.cancel()
        upstream?.cancel()
        upstream = nil
        onClose(self)
    }

    // MARK: - Client → upstream

    private func readClient() {
        client.receive(minimumIncompleteLength: 1, maximumLength: Self.readSize) { [weak self] data, _, isComplete, error in
            guard let self, !isClosed else { return }

            if let data {
                buffer.append(contentsOf: data)
            }
            let outgoing = process()
            guard !isClosed else { return }

            if isComplete || error != nil {
                // The client is done sending; let the upstream finish its
                // response, then the upstream's EOF closes everything.
                guard let upstream else {
                    close()
                    return
                }
                send(outgoing, to: upstream)
                upstream.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .idempotent)
                return
            }

            guard let upstream, !outgoing.isEmpty else {
                readClient()
                return
            }
            send(outgoing, to: upstream) { [weak self] in
                self?.readClient()
            }
        }
    }

    /// Consumes buffered client bytes and returns what to forward upstream.
    private func process() -> [UInt8] {
        var outgoing: [UInt8] = []

        while !buffer.isEmpty, !isClosed {
            switch phase {
            case .head:
                guard let end = buffer.firstRange(of: headTerminator) else {
                    if buffer.count > Self.maxHeadBytes {
                        reject(431, "Request Header Fields Too Large", "request headers are too large")
                    }
                    return outgoing
                }
                guard let head = HTTPRequestHead(buffer[..<end.lowerBound]) else {
                    reject(400, "Bad Request", "malformed request")
                    return outgoing
                }
                buffer.removeFirst(end.upperBound)

                guard let host = head.host else {
                    reject(400, "Bad Request", "missing host header")
                    return outgoing
                }
                guard let port = resolvePort(host) else {
                    reject(404, "Not Found", "no active route for host \(host)")
                    return outgoing
                }

                if port != upstreamPort {
                    connectUpstream(port: port)
                }
                outgoing += head.serialized(upstreamPort: port)

                if head.isUpgrade {
                    phase = .tunnel
                } else if case .none = head.bodyFraming {
                    phase = .head
                } else {
                    phase = .body(head.bodyFraming)
                }

            case let .body(.length(remaining)):
                let count = min(remaining, buffer.count)
                outgoing += buffer[..<count]
                buffer.removeFirst(count)
                phase = count == remaining ? .head : .body(.length(remaining - count))

            case .body(.chunked(var scanner)):
                guard let count = scanner.scan(buffer[...]) else {
                    reject(400, "Bad Request", "malformed chunked request body")
                    return outgoing
                }
                outgoing += buffer[..<count]
                buffer.removeFirst(count)
                phase = scanner.isComplete ? .head : .body(.chunked(scanner))

            case .body(.none):
                phase = .head

            case .tunnel:
                outgoing += buffer
                buffer.removeAll()
            }
        }

        return outgoing
    }

    private func send(_ bytes: [UInt8], to connection: NWConnection, then next: (() -> Void)? = nil) {
        guard !bytes.isEmpty else {
            next?()
            return
        }
        connection.send(content: Data(bytes), completion: .contentProcessed { [weak self] error in
            // Upstream failures are reported by its state handler.
            guard let self, !isClosed, error == nil else { return }
            next?()
        })
    }

    // MARK: - Upstream → client

    private func connectUpstream(port: UInt16) {
        upstream?.cancel()

        let parameters = NWParameters.tcp
        parameters.preferNoProxies = true
        // "localhost" lets Network.framework try both ::1 and 127.0.0.1, so
        // dev servers bound to either family work.
        let connection = NWConnection(host: "localhost", port: NWEndpoint.Port(rawValue: port)!, using: parameters)
        upstream = connection
        upstreamPort = port
        upstreamHasResponded = false

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection, connection === upstream else { return }
            switch state {
            case let .waiting(error), let .failed(error):
                if upstreamHasResponded {
                    close()
                } else {
                    reject(502, "Bad Gateway", "upstream request failed: could not connect to localhost:\(port): \(error.reason)")
                }
            default:
                break
            }
        }
        connection.start(queue: queue)
        readUpstream(connection)
    }

    private func readUpstream(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.readSize) { [weak self] data, _, isComplete, error in
            guard let self, !isClosed, connection === upstream else { return }

            let finished = isComplete || error != nil
            guard let data, !data.isEmpty else {
                if finished {
                    upstreamFinished()
                } else {
                    readUpstream(connection)
                }
                return
            }

            upstreamHasResponded = true
            client.send(content: data, completion: .contentProcessed { [weak self] sendError in
                guard let self, !isClosed else { return }
                if sendError != nil {
                    close()
                } else if finished {
                    upstreamFinished()
                } else {
                    readUpstream(connection)
                }
            })
        }
    }

    private func upstreamFinished() {
        guard upstreamHasResponded else {
            reject(502, "Bad Gateway", "upstream closed the connection without responding")
            return
        }
        client.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { [weak self] _ in
            self?.close()
        })
    }

    /// Answers the client directly and closes the connection.
    private func reject(_ status: Int, _ reason: String, _ message: String) {
        guard !isClosed else { return }
        isClosed = true
        upstream?.cancel()
        upstream = nil
        buffer.removeAll()

        let client = client
        client.send(
            content: Data(HTTPResponse.text(status, reason, message)),
            contentContext: .finalMessage,
            isComplete: true,
            completion: .contentProcessed { _ in client.cancel() }
        )
        onClose(self)
    }
}
