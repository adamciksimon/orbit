//
//  HostsFile.swift
//  Orbit
//

import Foundation

/// Keeps a marked block in /etc/hosts that points Orbit's non-`.local`
/// domains at 127.0.0.1. Lines outside the block are never touched.
nonisolated enum HostsFile {
    enum Failure: LocalizedError {
        case cancelledByUser
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .cancelledByUser:
                "Administrator approval was cancelled."
            case let .writeFailed(output):
                output.isEmpty ? "Updating /etc/hosts failed." : "Updating /etc/hosts failed: \(output)"
            }
        }
    }

    private static let url = URL(filePath: "/etc/hosts")
    private static let beginMarker = "# >>> Orbit (managed by Orbit.app, do not edit)"
    private static let endMarker = "# <<< Orbit"

    /// Hostnames /etc/hosts maps to a loopback address.
    static func loopbackHostnames() -> Set<String> {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        var hostnames: Set<String> = []
        for line in text.split(whereSeparator: \.isNewline) {
            let content = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            let fields = content.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let address = fields.first, address == "127.0.0.1" || address == "::1" else { continue }
            for hostname in fields.dropFirst() {
                hostnames.insert(Domain.normalize(String(hostname)))
            }
        }
        return hostnames
    }

    /// Replaces Orbit's block with entries for `hostnames`, after the user
    /// approves the administrator prompt, and flushes the DNS cache.
    static func update(hostnames: [String]) async throws {
        let current = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let updated = contents(replacingBlockIn: current, with: hostnames)

        let staged = FileManager.default.temporaryDirectory.appending(path: "orbit-hosts-\(UUID().uuidString)")
        try updated.write(to: staged, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: staged) }

        // `cat >` keeps the file's owner and permissions.
        let command = "cat \(ProcessRunner.shellQuote(staged.path)) > /etc/hosts"
            + " && { dscacheutil -flushcache; killall -HUP mDNSResponder; true; }"
        let output = try await ProcessRunner.runAsAdministrator(command)

        guard output.status == 0 else {
            // osascript reports error -128 when the user dismisses the prompt.
            if output.text.contains("-128") {
                throw Failure.cancelledByUser
            }
            throw Failure.writeFailed(output.text)
        }
    }

    private static func contents(replacingBlockIn text: String, with hostnames: [String]) -> String {
        var lines = text.components(separatedBy: "\n")
        if let begin = lines.firstIndex(of: beginMarker),
           let end = lines[begin...].firstIndex(of: endMarker) {
            lines.removeSubrange(begin...end)
        }
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }

        if !hostnames.isEmpty {
            lines.append("")
            lines.append(beginMarker)
            lines += hostnames.map { "127.0.0.1\t\($0)" }
            lines.append(endMarker)
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
