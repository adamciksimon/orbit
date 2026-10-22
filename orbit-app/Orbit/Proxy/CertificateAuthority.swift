//
//  CertificateAuthority.swift
//  Orbit
//

import Foundation
@preconcurrency import Security

/// Wraps the bundled `mkcert` binary: owns Orbit's local CA under
/// `~/.orbit/mkcert` and issues the proxy's TLS identity.
actor CertificateAuthority {
    enum Failure: LocalizedError {
        case missingMkcert
        case commandFailed(String, String)
        case unreadableIdentity(OSStatus)
        case missingRoot
        case trustFailed(OSStatus)
        case cancelledByUser

        var errorDescription: String? {
            switch self {
            case .missingMkcert:
                "The bundled mkcert executable is missing from the app bundle."
            case let .commandFailed(command, output):
                output.isEmpty ? "\(command) failed." : "\(command) failed: \(output)"
            case let .unreadableIdentity(status):
                "Could not read the generated certificate (OSStatus \(status))."
            case .missingRoot:
                "Orbit's root certificate has not been created yet."
            case let .trustFailed(status):
                "macOS refused to trust the certificate (\(SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"))."
            case .cancelledByUser:
                "Approval was cancelled."
            }
        }
    }

    /// mkcert's fixed PKCS#12 password. mkcert always writes `-pkcs12` files
    /// with it and has no option to change it, so this must stay "changeit"
    /// or the proxy can't read its own certificate.
    private static let pkcs12Password = "changeit"

    nonisolated static let dataDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".orbit", directoryHint: .isDirectory)

    /// Where Orbit kept its data before version 0.4.2.
    private nonisolated static let legacyDataDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".localcan", directoryHint: .isDirectory)

    /// Moves data from the old `~/.localcan` folder to `~/.orbit` once, so
    /// existing projects and the already trusted CA carry over without a new
    /// trust prompt. Leaves everything alone if `~/.orbit` already exists.
    nonisolated static func migrateLegacyDataDirectory() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacyDataDirectory.path),
              !fileManager.fileExists(atPath: dataDirectory.path)
        else { return }
        try? fileManager.moveItem(at: legacyDataDirectory, to: dataDirectory)
    }

    private let caRoot = dataDirectory.appending(path: "mkcert", directoryHint: .isDirectory)
    private let tlsDirectory = dataDirectory.appending(path: "tls", directoryHint: .isDirectory)
    private var identityURL: URL { tlsDirectory.appending(path: "proxy.p12") }
    private var rootCertificateURL: URL { Self.rootCertificateURL }

    /// The CA certificate other devices install to trust Orbit's domains.
    nonisolated static let rootCertificateURL = dataDirectory.appending(path: "mkcert/rootCA.pem")

    private var mkcertURL: URL {
        get throws {
            guard let url = Bundle.main.url(forAuxiliaryExecutable: "mkcert") else {
                throw Failure.missingMkcert
            }
            return url
        }
    }

    /// Issues a certificate covering `hostnames` (plus localhost), creating
    /// the CA first if needed, and loads it as a TLS identity.
    func makeIdentity(for hostnames: [String]) async throws -> SecIdentity {
        try FileManager.default.createDirectory(at: caRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tlsDirectory, withIntermediateDirectories: true)

        var names = ["localhost", "127.0.0.1"]
        for hostname in hostnames where !names.contains(hostname) {
            names.append(hostname)
        }

        let output = try await ProcessRunner.run(
            try mkcertURL,
            arguments: ["-pkcs12", "-p12-file", identityURL.path] + names,
            environment: ["CAROOT": caRoot.path]
        )
        guard output.status == 0 else {
            throw Failure.commandFailed("mkcert", output.lastLine)
        }

        return try loadIdentity()
    }

    /// Whether macOS trusts Orbit's root CA for the current user.
    func isRootTrusted() -> Bool {
        guard let certificate = loadRootCertificate() else {
            return false
        }

        var trust: SecTrust?
        guard SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust) == errSecSuccess,
              let trust
        else {
            return false
        }
        return SecTrustEvaluateWithError(trust, nil)
    }

    /// Adds the root CA to the login keychain and marks it trusted for this
    /// user. macOS asks for the user's password or Touch ID; it only allows
    /// trust changes from an interactive app, which is why running
    /// `mkcert -install` from a root shell can't do this.
    func installRoot() async throws {
        guard let certificate = loadRootCertificate() else {
            throw Failure.missingRoot
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw Failure.trustFailed(addStatus)
        }

        // The call blocks until the user answers the system prompt, so keep
        // it off the cooperative thread pool.
        let trustStatus = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: SecTrustSettingsSetTrustSettings(certificate, .user, nil))
            }
        }
        switch trustStatus {
        case errSecSuccess:
            return
        case errAuthorizationCanceled, errSecUserCanceled:
            throw Failure.cancelledByUser
        default:
            throw Failure.trustFailed(trustStatus)
        }
    }

    private func loadRootCertificate() -> SecCertificate? {
        guard
            let pem = try? String(contentsOf: rootCertificateURL, encoding: .utf8),
            let der = Self.derFromPEM(pem)
        else {
            return nil
        }
        return SecCertificateCreateWithData(nil, der as CFData)
    }

    private func loadIdentity() throws -> SecIdentity {
        let data = try Data(contentsOf: identityURL)
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: Self.pkcs12Password,
            kSecImportToMemoryOnly as String: true,
        ]

        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess,
              let entries = items as? [[String: Any]],
              let identity = entries.first?[kSecImportItemIdentity as String]
        else {
            throw Failure.unreadableIdentity(status)
        }
        return identity as! SecIdentity
    }

    private static func derFromPEM(_ pem: String) -> Data? {
        let base64 = pem
            .split(whereSeparator: \.isNewline)
            .filter { !$0.hasPrefix("-----") }
            .joined()
        return Data(base64Encoded: base64)
    }
}
