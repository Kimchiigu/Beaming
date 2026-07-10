//
//  LocalNetworkHelper.swift
//  Beaming
//
//  Utility to retrieve the device's local WiFi IP address.
//  Used by the host to embed IP+port in the QR code so
//  App Clip guests can connect directly via TCP.
//

import Foundation

enum LocalNetworkHelper {
    /// Returns the device's local IPv4 address on the WiFi interface (en0),
    /// or `nil` if not connected to WiFi.
    static func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            // Only IPv4 (AF_INET) on the WiFi interface (en0)
            guard addrFamily == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name == "en0" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil, 0,
                NI_NUMERICHOST
            ) == 0 {
                address = String(cString: hostname)
            }
        }

        return address
    }
}
