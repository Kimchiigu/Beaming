//
//  AppClipURLHelper.swift
//  Beaming
//
//  Builds and parses App Clip invocation URLs.
//  Shared by the full app and the App Clip target.
//

import Foundation

enum AppClipURLHelper {
    /// The domain registered in your AASA file (GitHub Pages root).
    static let domain = "axelnakata.github.io"
    
    /// Build a Universal Link URL for a given room code.
    /// When `hostIP` and `port` are provided, they are appended so the App Clip
    /// can connect directly via TCP (bypassing Bonjour, which App Clips can't use).
    ///
    /// Example without host info:
    ///   "https://axelnakata.github.io/join?room=CeriaRubah::::ABCD-1234"
    /// Example with host info:
    ///   "https://axelnakata.github.io/join?room=CeriaRubah::::ABCD-1234&host=192.168.1.5&port=54321"
    static func buildJoinURL(roomCode: String, hostIP: String? = nil, port: UInt16? = nil) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/join"
        
        var queryItems = [URLQueryItem(name: "room", value: roomCode)]
        if let hostIP = hostIP, let port = port {
            queryItems.append(URLQueryItem(name: "host", value: hostIP))
            queryItems.append(URLQueryItem(name: "port", value: String(port)))
        }
        components.queryItems = queryItems
        
        return components.url?.absoluteString
            ?? "https://\(domain)/join?room=\(roomCode)"
    }
    
    /// Extract the room code from a string. Handles:
    /// - Full App Clip URL: "https://axelnakata.github.io/join?room=..."
    /// - Percent-encoded URLs (double-encoded edge cases)
    /// - Raw Bonjour service names as fallback (backward compat)
    static func extractRoomCode(from string: String) -> String? {
        // First, try standard URL parsing
        if let url = URL(string: string),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let roomCode = components.queryItems?.first(where: { $0.name == "room" })?.value,
           !roomCode.isEmpty {
            print("[AppClipURLHelper] Extracted room code: \(roomCode)")
            return roomCode
        }
        
        // Second, try percent-decoding the whole string first (double-encoding case)
        if let decoded = string.removingPercentEncoding, decoded != string {
            if let url = URL(string: decoded),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let roomCode = components.queryItems?.first(where: { $0.name == "room" })?.value,
               !roomCode.isEmpty {
                print("[AppClipURLHelper] Extracted room code (after decoding): \(roomCode)")
                return roomCode
            }
        }
        
        // Third, manual regex fallback — grab everything after "room="
        if string.contains("room=") {
            let parts = string.components(separatedBy: "room=")
            if let raw = parts.last, !raw.isEmpty {
                // Strip any trailing query params
                let code = raw.components(separatedBy: "&").first ?? raw
                let decoded = code.removingPercentEncoding ?? code
                if !decoded.isEmpty {
                    print("[AppClipURLHelper] Extracted room code (regex fallback): \(decoded)")
                    return decoded
                }
            }
        }
        
        print("[AppClipURLHelper] Failed to extract room code from: \(string)")
        return nil
    }
    
    /// Extract the host IP and port from an App Clip URL.
    /// Returns `nil` if the URL doesn't contain host info (e.g., old-format QR codes).
    static func extractHostInfo(from string: String) -> (host: String, port: UInt16)? {
        let urlString = string.removingPercentEncoding ?? string
        
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return nil
        }
        
        guard let hostValue = items.first(where: { $0.name == "host" })?.value,
              !hostValue.isEmpty,
              let portString = items.first(where: { $0.name == "port" })?.value,
              let portValue = UInt16(portString) else {
            return nil
        }
        
        print("[AppClipURLHelper] Extracted host info: \(hostValue):\(portValue)")
        return (host: hostValue, port: portValue)
    }
}

