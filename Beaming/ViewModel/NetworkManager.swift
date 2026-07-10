//
//  NetworkManager.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import Foundation
import Network
import Observation

/// Manages Bonjour discovery, TCP listener (host), and TCP connections (guest).
@Observable
class NetworkManager {
    
    // MARK: - Properties
    
    /// Rooms discovered via Bonjour browsing
    var discoveredRooms: [NWBrowser.Result] = []
    
    /// The port the listener is bound to (set when listener reaches .ready).
    /// Used to embed in QR codes for direct App Clip TCP connections.
    var listenerPort: UInt16?
    
    /// Connections to peers (host keeps all guest connections, guest keeps one host connection)
    var peerConnections: [UUID: NWConnection] = [:]
    
    /// Callback when a message is received from a peer
    var onMessageReceived: ((NetworkMessage, UUID?) -> Void)?
    
    /// Callback when a peer disconnects
    var onPeerDisconnected: ((UUID) -> Void)?
    
    /// Callback when a new connection is established (host side)
    var onNewConnection: ((NWConnection) -> Void)?
    
    private var listener: NWListener?
    private var browser: NWBrowser?
    private let serviceType = "_beaming._tcp"
    private var connectionToPeerID: [ObjectIdentifier: UUID] = [:]
    
    // MARK: - Bonjour Advertising (Host)
    
    /// Start advertising a room via Bonjour so other devices can find it.
    func startAdvertising(roomID: UUID, hostName: String) {
        do {
            let tcpOptions = NWProtocolTCP.Options()
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.includePeerToPeer = true
            
            listener = try NWListener(using: params)
            
            // Encode host name directly in the service name (TXT records are unreliable)
            let serviceName = "\(hostName)::::\(roomID.uuidString)"
            listener?.service = NWListener.Service(
                name: serviceName,
                type: serviceType
            )
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.listenerPort = self?.listener?.port?.rawValue
                    print("[NetworkManager] Listener ready on port: \(self?.listenerPort ?? 0)")
                case .failed(let error):
                    print("[NetworkManager] Listener failed: \(error)")
                    self?.listener?.cancel()
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            listener?.start(queue: .main)
            print("[NetworkManager] Started advertising room: \(hostName)'s Room")
        } catch {
            print("[NetworkManager] Failed to create listener: \(error)")
        }
    }
    
    /// Stop advertising (when room is ended or host leaves).
    func stopAdvertising() {
        listener?.cancel()
        listener = nil
        print("[NetworkManager] Stopped advertising")
    }
    
    // MARK: - Bonjour Browsing (Discovery)
    
    /// Start browsing for available rooms.
    func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: params)
        
        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[NetworkManager] Browser ready")
            case .failed(let error):
                print("[NetworkManager] Browser failed: \(error)")
            default:
                break
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.discoveredRooms = Array(results)
            }
        }
        
        browser?.start(queue: .main)
        print("[NetworkManager] Started browsing for rooms")
    }
    
    /// Stop browsing.
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        print("[NetworkManager] Stopped browsing")
    }
    
    // MARK: - Connect to Room (Guest)
    
    /// Connect to a discovered room as a guest.
    func connectToRoom(endpoint: NWEndpoint, localUser: User) {
        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.includePeerToPeer = true
        
        let connection = NWConnection(to: endpoint, using: params)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[NetworkManager] Connected to host")
                // Send join request
                let message = NetworkMessage.joinRequest(user: localUser)
                self?.sendMessage(message, on: connection)
                self?.receiveMessages(on: connection, peerID: nil)
            case .failed(let error):
                print("[NetworkManager] Connection failed: \(error)")
                connection.cancel()
            case .cancelled:
                print("[NetworkManager] Connection cancelled")
            default:
                break
            }
        }
        
        // Store temporarily with a placeholder — will be updated after join response
        connection.start(queue: .main)
    }
    
    // MARK: - Message Handling
    
    /// Send a message over a specific connection.
    func sendMessage(_ message: NetworkMessage, on connection: NWConnection) {
        guard let data = message.encode() else {
            print("[NetworkManager] Failed to encode message")
            return
        }
        
        // Prefix with 4-byte length header for framing
        var length = UInt32(data.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)
        let framedData = lengthData + data
        
        connection.send(content: framedData, completion: .contentProcessed { error in
            if let error = error {
                print("[NetworkManager] Send error: \(error)")
            }
        })
    }
    
    /// Broadcast a message to all connected peers.
    func broadcastMessage(_ message: NetworkMessage) {
        for (_, connection) in peerConnections {
            sendMessage(message, on: connection)
        }
    }
    
    /// Send a message to a specific peer by UUID.
    func sendMessageToPeer(_ message: NetworkMessage, peerID: UUID) {
        guard let connection = peerConnections[peerID] else {
            print("[NetworkManager] No connection found for peer \(peerID)")
            return
        }
        sendMessage(message, on: connection)
    }
    
    /// Register a connection with a peer ID (called after join handshake).
    func registerPeer(_ peerID: UUID, connection: NWConnection) {
        peerConnections[peerID] = connection
        connectionToPeerID[ObjectIdentifier(connection)] = peerID
    }
    
    /// Receive messages on a connection (recursive read loop).
    func receiveMessages(on connection: NWConnection, peerID: UUID?) {
        // Read 4-byte length header first
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] headerData, _, _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[NetworkManager] Receive header error: \(error)")
                self.handleDisconnection(connection: connection, peerID: peerID)
                return
            }
            
            guard let headerData = headerData, headerData.count == 4 else {
                self.handleDisconnection(connection: connection, peerID: peerID)
                return
            }
            
            let length = headerData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            // Now read the message body
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] bodyData, _, _, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("[NetworkManager] Receive body error: \(error)")
                    self.handleDisconnection(connection: connection, peerID: peerID)
                    return
                }
                
                if let bodyData = bodyData, let message = NetworkMessage.decode(from: bodyData) {
                    let resolvedPeerID = peerID ?? self.connectionToPeerID[ObjectIdentifier(connection)]
                    DispatchQueue.main.async {
                        self.onMessageReceived?(message, resolvedPeerID)
                    }
                }
                
                // Continue reading
                self.receiveMessages(on: connection, peerID: peerID)
            }
        }
    }
    
    // MARK: - Connection Management
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[NetworkManager] New peer connected")
                self?.onNewConnection?(connection)
                self?.receiveMessages(on: connection, peerID: nil)
            case .failed, .cancelled:
                let peerID = self?.connectionToPeerID[ObjectIdentifier(connection)]
                self?.handleDisconnection(connection: connection, peerID: peerID)
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func handleDisconnection(connection: NWConnection, peerID: UUID?) {
        let resolvedPeerID = peerID ?? connectionToPeerID[ObjectIdentifier(connection)]
        connectionToPeerID.removeValue(forKey: ObjectIdentifier(connection))
        
        if let resolvedPeerID = resolvedPeerID {
            peerConnections.removeValue(forKey: resolvedPeerID)
            DispatchQueue.main.async {
                self.onPeerDisconnected?(resolvedPeerID)
            }
        }
    }
    
    /// Disconnect a specific peer.
    func disconnectPeer(_ peerID: UUID) {
        peerConnections[peerID]?.cancel()
        peerConnections.removeValue(forKey: peerID)
    }
    
    /// Disconnect all peers and clean up.
    func disconnectAll() {
        for (_, connection) in peerConnections {
            connection.cancel()
        }
        peerConnections.removeAll()
        connectionToPeerID.removeAll()
        stopAdvertising()
        stopBrowsing()
    }
    
    /// Store the guest's single connection to the host.
    var hostConnection: NWConnection?
    
    func connectToHost(endpoint: NWEndpoint, localUser: User, completion: @escaping (Bool) -> Void) {
        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.includePeerToPeer = true
        
        let connection = NWConnection(to: endpoint, using: params)
        self.hostConnection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[NetworkManager] Connected to host, sending join request")
                let message = NetworkMessage.joinRequest(user: localUser)
                self?.sendMessage(message, on: connection)
                self?.receiveMessages(on: connection, peerID: nil)
                DispatchQueue.main.async {
                    completion(true)
                }
            case .failed(let error):
                print("[NetworkManager] Failed to connect to host: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            case .waiting(let error):
                print("[NetworkManager] Connection waiting: \(error) — likely awaiting local network permission")
            case .preparing:
                print("[NetworkManager] Connection preparing...")
            case .cancelled:
                print("[NetworkManager] Host connection cancelled")
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    /// Send a message to the host (guest side).
    func sendToHost(_ message: NetworkMessage) {
        guard let connection = hostConnection else {
            print("[NetworkManager] No host connection")
            return
        }
        sendMessage(message, on: connection)
    }
    
    /// Disconnect from the host (guest leaving).
    func disconnectFromHost() {
        hostConnection?.cancel()
        hostConnection = nil
    }
}
