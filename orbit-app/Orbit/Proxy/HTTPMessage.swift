//
//  HTTPMessage.swift
//  Orbit
//

import Foundation
import Network

nonisolated let crlf: [UInt8] = [13, 10]
nonisolated let headTerminator: [UInt8] = [13, 10, 13, 10]

nonisolated extension Array where Element == UInt8 {
    func firstRange(of pattern: [UInt8], from start: Int = 0) -> Range<Int>? {
        guard pattern.count <= count else { return nil }
        var index = start
        while index <= count - pattern.count {
            if self[index] == pattern[0], self[index..<index + pattern.count].elementsEqual(pattern) {
                return index..<index + pattern.count
            }
            index += 1
        }
        return nil
    }
}

/// The request line and headers of an HTTP/1.x request.
nonisolated struct HTTPRequestHead {
    var method: String
    var target: String
    var version: String
    var headers: [(name: String, value: String)]

    init?(_ bytes: ArraySlice<UInt8>) {
        let text = String(decoding: bytes, as: UTF8.self)
        var lines = text.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ", omittingEmptySubsequences: true)
        guard requestLine.count == 3, requestLine[2].hasPrefix("HTTP/") else {
            return nil
        }

        method = String(requestLine[0])
        target = String(requestLine[1])
        version = String(requestLine[2])
        headers = lines.compactMap { line in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : (name, value)
        }
    }

    func value(for name: String) -> String? {
        headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    /// The Host header without its port, normalized for route lookup.
    var host: String? {
        guard let host = value(for: "Host"), !host.isEmpty else { return nil }
        if host.hasPrefix("["), let end = host.firstIndex(of: "]") {
            return String(host[host.index(after: host.startIndex)..<end])
        }
        return Domain.normalize(String(host.split(separator: ":", maxSplits: 1)[0]))
    }

    var isUpgrade: Bool {
        let connection = value(for: "Connection")?.lowercased() ?? ""
        return connection.contains("upgrade") && value(for: "Upgrade") != nil
    }

    var bodyFraming: BodyFraming {
        if let encoding = value(for: "Transfer-Encoding"), encoding.lowercased().contains("chunked") {
            return .chunked(ChunkedBodyScanner())
        }
        if let length = value(for: "Content-Length").flatMap(Int.init), length > 0 {
            return .length(length)
        }
        return .none
    }

    /// Serializes the head for the upstream server, replacing `Host` so dev
    /// servers that check it (Vite, webpack) accept the request.
    func serialized(upstreamPort: UInt16) -> [UInt8] {
        var head = "\(method) \(target) \(version)\r\n"
        head += "Host: localhost:\(upstreamPort)\r\n"
        for (name, value) in headers {
            let lowercased = name.lowercased()
            if lowercased == "host" || lowercased.hasPrefix("x-forwarded-") {
                continue
            }
            head += "\(name): \(value)\r\n"
        }
        if let host = value(for: "Host") {
            head += "X-Forwarded-Host: \(host)\r\n"
        }
        head += "X-Forwarded-Proto: https\r\n\r\n"
        return Array(head.utf8)
    }
}

nonisolated enum BodyFraming {
    case none
    case length(Int)
    case chunked(ChunkedBodyScanner)
}

/// Finds where a chunked body ends without decoding it, so the bytes can be
/// forwarded unchanged.
nonisolated struct ChunkedBodyScanner {
    private enum State {
        case sizeLine
        case data(Int)
        case dataTerminator(Int)
        case trailerLine(isEmpty: Bool)
        case done
    }

    private var state = State.sizeLine
    private var line: [UInt8] = []

    var isComplete: Bool {
        if case .done = state { return true }
        return false
    }

    /// Scans `bytes` and returns how many of them belong to the body.
    /// Returns nil if the framing is malformed.
    mutating func scan(_ bytes: ArraySlice<UInt8>) -> Int? {
        var index = bytes.startIndex

        while index < bytes.endIndex {
            switch state {
            case .done:
                return index - bytes.startIndex

            case let .data(remaining):
                let count = min(remaining, bytes.endIndex - index)
                index += count
                state = remaining == count ? .dataTerminator(2) : .data(remaining - count)

            case let .dataTerminator(remaining):
                index += 1
                state = remaining == 1 ? .sizeLine : .dataTerminator(remaining - 1)

            case .sizeLine:
                let byte = bytes[index]
                index += 1
                guard byte == 10 else {
                    line.append(byte)
                    guard line.count < 1024 else { return nil }
                    continue
                }
                let text = String(decoding: line, as: UTF8.self)
                line.removeAll()
                let sizeText = text.split(separator: ";", maxSplits: 1).first ?? ""
                guard let size = Int(sizeText.trimmingCharacters(in: .whitespacesAndNewlines), radix: 16) else {
                    return nil
                }
                state = size == 0 ? .trailerLine(isEmpty: true) : .data(size)

            case let .trailerLine(isEmpty):
                let byte = bytes[index]
                index += 1
                if byte == 10 {
                    state = isEmpty ? .done : .trailerLine(isEmpty: true)
                } else if byte != 13 {
                    state = .trailerLine(isEmpty: false)
                }
            }
        }

        return index - bytes.startIndex
    }
}

nonisolated enum HTTPResponse {
    static func text(_ status: Int, _ reason: String, _ body: String) -> [UInt8] {
        let body = Array(body.utf8)
        let head = "HTTP/1.1 \(status) \(reason)\r\n"
            + "Content-Type: text/plain; charset=utf-8\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n\r\n"
        return Array(head.utf8) + body
    }
}

nonisolated extension NWError {
    /// "Connection refused" rather than NWError's generic description.
    var reason: String {
        switch self {
        case let .posix(code):
            String(cString: strerror(code.rawValue))
        default:
            localizedDescription
        }
    }
}
