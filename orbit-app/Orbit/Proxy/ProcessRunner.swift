//
//  ProcessRunner.swift
//  Orbit
//

import Foundation

nonisolated enum ProcessRunner {
    struct Output {
        var status: Int32
        var text: String

        var lastLine: String {
            text.split(whereSeparator: \.isNewline).last.map(String.init) ?? ""
        }
    }

    /// Runs `executable` to completion, capturing stdout and stderr together.
    static func run(_ executable: URL, arguments: [String], environment: [String: String] = [:]) async throws -> Output {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: Output(status: process.terminationStatus, text: text))
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    /// Runs a shell command as root. macOS shows its administrator prompt.
    static func runAsAdministrator(_ command: String) async throws -> Output {
        let script = "do shell script \(appleScriptQuote(command)) with administrator privileges"
        return try await run(URL(filePath: "/usr/bin/osascript"), arguments: ["-e", script])
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private static func appleScriptQuote(_ value: String) -> String {
        var quoted = "\""
        for character in value {
            switch character {
            case "\\": quoted += "\\\\"
            case "\"": quoted += "\\\""
            case "\n": quoted += "\\n"
            case "\r": quoted += "\\r"
            default: quoted.append(character)
            }
        }
        return quoted + "\""
    }
}
