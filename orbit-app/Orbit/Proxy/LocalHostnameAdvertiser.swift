//
//  LocalHostnameAdvertiser.swift
//  Orbit
//

import Foundation
import dnssd

/// Publishes `<name>.local → 127.0.0.1` records through mDNSResponder so
/// `.local` proxy domains resolve on this Mac without editing /etc/hosts.
/// Records are registered local-only and vanish when the app quits.
nonisolated final class LocalHostnameAdvertiser: @unchecked Sendable {
    private let queue = DispatchQueue(label: "co.outloud.Orbit.mdns")

    private var connection: DNSServiceRef?
    private var records: [String: DNSRecordRef] = [:]
    private var hostnames: Set<String> = []

    deinit {
        if let connection {
            DNSServiceRefDeallocate(connection)
        }
    }

    func update(hostnames: Set<String>) {
        queue.async {
            self.hostnames = hostnames
            self.apply()
        }
    }

    private func apply() {
        guard let connection = openConnection() else { return }

        for (hostname, record) in records where !hostnames.contains(hostname) {
            DNSServiceRemoveRecord(connection, record, 0)
            records[hostname] = nil
        }

        for hostname in hostnames.sorted() where records[hostname] == nil {
            register(hostname, on: connection)
        }
    }

    private func openConnection() -> DNSServiceRef? {
        if let connection {
            return connection
        }

        var connection: DNSServiceRef?
        let error = DNSServiceCreateConnection(&connection)
        guard error == kDNSServiceErr_NoError, let connection else {
            return nil
        }
        DNSServiceSetDispatchQueue(connection, queue)
        self.connection = connection
        return connection
    }

    private func register(_ hostname: String, on connection: DNSServiceRef) {
        var record: DNSRecordRef?
        var address: [UInt8] = [127, 0, 0, 1]
        let error = DNSServiceRegisterRecord(
            connection,
            &record,
            DNSServiceFlags(kDNSServiceFlagsUnique),
            kDNSServiceInterfaceIndexLocalOnly,
            hostname + ".",
            UInt16(kDNSServiceType_A),
            UInt16(kDNSServiceClass_IN),
            UInt16(address.count),
            &address,
            120,
            { _, record, _, error, context in
                guard error != kDNSServiceErr_NoError, let context else { return }
                let advertiser = Unmanaged<LocalHostnameAdvertiser>.fromOpaque(context).takeUnretainedValue()
                advertiser.registrationFailed(record, error: error)
            },
            Unmanaged.passUnretained(self).toOpaque()
        )

        if error == kDNSServiceErr_NoError, let record {
            records[hostname] = record
        }
    }

    /// Called on `queue` by mDNSResponder.
    private func registrationFailed(_ record: DNSRecordRef?, error: DNSServiceErrorType) {
        if error == kDNSServiceErr_ServiceNotRunning, let connection {
            // mDNSResponder restarted: reconnect and register everything again.
            DNSServiceRefDeallocate(connection)
            self.connection = nil
            records.removeAll()
            apply()
            return
        }

        if let hostname = records.first(where: { $0.value == record })?.key {
            records[hostname] = nil
        }
    }
}
