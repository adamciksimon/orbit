//
//  LocalHostnameAdvertiser.swift
//  Orbit
//

import Foundation
import Network
import dnssd

/// Publishes `.local` proxy domains through mDNSResponder so they resolve
/// without editing /etc/hosts.
///
/// By default the records are local-only and point at `127.0.0.1` and `::1`,
/// so only this Mac sees them. When shared, they are announced on the Mac's
/// Wi-Fi and Ethernet interfaces with its addresses there, so other devices on
/// the network can open the same names. Records vanish when the app quits.
///
/// Both address families matter: browsers ask for A and AAAA together, and an
/// unanswered AAAA query keeps waiting on multicast DNS for 5 seconds before
/// the lookup completes.
nonisolated final class LocalHostnameAdvertiser: @unchecked Sendable {
    private struct Address: Hashable {
        var interfaceIndex: UInt32
        var type: Int
        var bytes: [UInt8]
        var description: String
    }

    private static let loopback = [
        Address(interfaceIndex: kDNSServiceInterfaceIndexLocalOnly, type: kDNSServiceType_A, bytes: [127, 0, 0, 1], description: "127.0.0.1"),
        Address(interfaceIndex: kDNSServiceInterfaceIndexLocalOnly, type: kDNSServiceType_AAAA, bytes: Array(repeating: 0, count: 15) + [1], description: "::1"),
    ]

    private let queue = DispatchQueue(label: "co.outloud.Orbit.mdns")
    /// Reports the IPv4 addresses other devices reach this Mac at, or an
    /// empty list when not shared (or not on a network).
    private let onSharedAddresses: @Sendable ([String]) -> Void

    private var connection: DNSServiceRef?
    private var records: [String: [DNSRecordRef]] = [:]
    private var hostnames: Set<String> = []
    private var isShared = false
    private var addresses = loopback
    private var pathMonitor: NWPathMonitor?

    init(onSharedAddresses: @escaping @Sendable ([String]) -> Void) {
        self.onSharedAddresses = onSharedAddresses
    }

    deinit {
        pathMonitor?.cancel()
        if let connection {
            DNSServiceRefDeallocate(connection)
        }
    }

    func update(hostnames: Set<String>, shared: Bool) {
        queue.async {
            self.hostnames = hostnames
            if shared != self.isShared {
                self.isShared = shared
                self.watchNetwork(shared)
                self.refreshAddressesAndRecords()
            }
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

    // MARK: - Addresses

    private func watchNetwork(_ watch: Bool) {
        pathMonitor?.cancel()
        pathMonitor = nil
        guard watch else { return }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            // Called on `queue`. Interface addresses can settle a moment after
            // the path changes, so look again shortly after.
            self?.refreshAddressesAndRecords()
            self?.queue.asyncAfter(deadline: .now() + 2) { self?.refreshAddressesAndRecords() }
        }
        monitor.start(queue: queue)
        pathMonitor = monitor
    }

    private func refreshAddressesAndRecords() {
        guard refreshAddresses(), let connection else { return }
        for hostname in records.keys {
            unregister(hostname, on: connection)
        }
        apply()
    }

    /// Returns whether the addresses changed.
    @discardableResult
    private func refreshAddresses() -> Bool {
        let shared = isShared ? Self.networkAddresses() : []
        // Offline, keep the names working on this Mac.
        let updated = shared.isEmpty ? Self.loopback : shared
        onSharedAddresses(shared.filter { $0.type == kDNSServiceType_A }.map(\.description))
        guard updated != addresses else { return false }
        addresses = updated
        return true
    }

    /// The Mac's addresses on its Wi-Fi and Ethernet interfaces (`en*`), which
    /// leaves out VPN tunnels, AWDL and other point-to-point links.
    private static func networkAddresses() -> [Address] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }

        var addresses: [Address] = []
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = entry.pointee
            let flags = Int32(interface.ifa_flags)
            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en"),
                  flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0,
                  let socketAddress = interface.ifa_addr
            else { continue }

            let index = if_nametoindex(interface.ifa_name)
            switch Int32(socketAddress.pointee.sa_family) {
            case AF_INET:
                let bytes = socketAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    withUnsafeBytes(of: $0.pointee.sin_addr) { Array($0) }
                }
                // 169.254.x.x is self-assigned on a link with no network
                // (an idle Thunderbolt bridge, say); nothing else can reach it.
                if bytes[0] == 169, bytes[1] == 254 {
                    continue
                }
                let description = bytes.map(String.init).joined(separator: ".")
                addresses.append(Address(interfaceIndex: index, type: kDNSServiceType_A, bytes: bytes, description: description))
            case AF_INET6:
                let bytes = socketAddress.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    withUnsafeBytes(of: $0.pointee.sin6_addr) { Array($0) }
                }
                let description = IPv6Address(Data(bytes)).map { "\($0)" } ?? ""
                addresses.append(Address(interfaceIndex: index, type: kDNSServiceType_AAAA, bytes: bytes, description: description))
            default:
                continue
            }
        }
        return addresses
    }

    // MARK: - Records

    private func register(_ hostname: String, on connection: DNSServiceRef) {
        var registered: [DNSRecordRef] = []
        for address in addresses {
            guard let record = registerRecord(hostname, address: address, on: connection) else {
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

    private func registerRecord(_ hostname: String, address: Address, on connection: DNSServiceRef) -> DNSRecordRef? {
        var record: DNSRecordRef?
        var bytes = address.bytes
        let error = DNSServiceRegisterRecord(
            connection,
            &record,
            DNSServiceFlags(kDNSServiceFlagsUnique),
            address.interfaceIndex,
            hostname + ".",
            UInt16(address.type),
            UInt16(kDNSServiceClass_IN),
            UInt16(bytes.count),
            &bytes,
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

        // Drop the hostname's other records too, so the next update registers
        // them all again.
        if let connection, let record, let hostname = records.first(where: { $0.value.contains(record) })?.key {
            records[hostname]?.removeAll { $0 == record }
            unregister(hostname, on: connection)
        }
    }
}
