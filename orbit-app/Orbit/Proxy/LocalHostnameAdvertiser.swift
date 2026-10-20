//
//  LocalHostnameAdvertiser.swift
//  Orbit
//

import Foundation
import dnssd

/// Publishes `<name>.local → 127.0.0.1` and `::1` records through
/// mDNSResponder so `.local` proxy domains resolve on this Mac without editing
/// /etc/hosts. Records are registered local-only and vanish when the app quits.
///
/// Both address families matter: browsers ask for A and AAAA together, and an
/// unanswered AAAA query keeps waiting on multicast DNS for 5 seconds before
/// the lookup completes.
nonisolated final class LocalHostnameAdvertiser: @unchecked Sendable {
    private let queue = DispatchQueue(label: "co.outloud.Orbit.mdns")

    private var connection: DNSServiceRef?
    private var records: [String: [DNSRecordRef]] = [:]
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

        for hostname in records.keys where !hostnames.contains(hostname) {
            unregister(hostname, on: connection)
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
        let loopbackV4: [UInt8] = [127, 0, 0, 1]
        let loopbackV6: [UInt8] = Array(repeating: 0, count: 15) + [1]

        var registered: [DNSRecordRef] = []
        for (type, address) in [(kDNSServiceType_A, loopbackV4), (kDNSServiceType_AAAA, loopbackV6)] {
            guard let record = registerRecord(hostname, type: type, address: address, on: connection) else {
                for record in registered {
                    DNSServiceRemoveRecord(connection, record, 0)
                }
                return
            }
            registered.append(record)
        }
        records[hostname] = registered
    }

    private func unregister(_ hostname: String, on connection: DNSServiceRef) {
        for record in records[hostname] ?? [] {
            DNSServiceRemoveRecord(connection, record, 0)
        }
        records[hostname] = nil
    }

    private func registerRecord(
        _ hostname: String,
        type: Int,
        address: [UInt8],
        on connection: DNSServiceRef
    ) -> DNSRecordRef? {
        var record: DNSRecordRef?
        var address = address
        let error = DNSServiceRegisterRecord(
            connection,
            &record,
            DNSServiceFlags(kDNSServiceFlagsUnique),
            kDNSServiceInterfaceIndexLocalOnly,
            hostname + ".",
            UInt16(type),
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

        return error == kDNSServiceErr_NoError ? record : nil
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

        // Drop the hostname's other record too, so the next update registers
        // both again.
        if let connection, let record, let hostname = records.first(where: { $0.value.contains(record) })?.key {
            records[hostname]?.removeAll { $0 == record }
            unregister(hostname, on: connection)
        }
    }
}
