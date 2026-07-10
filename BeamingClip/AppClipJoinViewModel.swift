//
//  AppClipJoinViewModel.swift
//  BeamingClip
//
//  Handles the App Clip join flow: receives URL → extracts room code + host IP/port
//  → requests Microphone → connects directly via TCP → produces a MeetingViewModel
//  for navigation.
//
//  NOTE: App Clips CANNOT use Bonjour service discovery (NWBrowser). Apple blocks
//  this API at runtime. Instead, the host's IP address and listener port are
//  embedded in the QR code URL, and the App Clip connects directly via TCP.
//

import Foundation
import Network
import Observation
import AVFoundation

@Observable
class AppClipJoinViewModel {
    var currentUser: User
    var activeMeetingVM: MeetingViewModel?
    var isConnecting = false
    var connectionFailed = false
    var showAlert = false
    var alertMessage = ""

    var onJoinSuccess: (() -> Void)?

    /// Whether URL was parsed successfully and roomCode is set.
    var hasValidRoom: Bool { roomCode != nil }

    private(set) var roomCode: String?
    private var hostIP: String?
    private var hostPort: UInt16?
    private var hasPermission = false
    private var networkManager: NetworkManager?

    init(user: User) {
        self.currentUser = user
    }

    /// Called when the App Clip receives the invocation URL.
    func handleInvocationURL(_ url: URL) {
        print("[AppClipJoinVM] Received URL: \(url.absoluteString)")

        guard let code = AppClipURLHelper.extractRoomCode(from: url.absoluteString) else {
            print("[AppClipJoinVM] Failed to extract room code from URL")
            alertMessage = "Kode QR tidak valid."
            return
        }

        print("[AppClipJoinVM] Extracted room code: \(code)")
        roomCode = code

        // Extract host IP and port for direct TCP connection
        if let hostInfo = AppClipURLHelper.extractHostInfo(from: url.absoluteString) {
            hostIP = hostInfo.host
            hostPort = hostInfo.port
            print("[AppClipJoinVM] Host info: \(hostInfo.host):\(hostInfo.port)")
        } else {
            print("[AppClipJoinVM] No host info in URL — will not be able to connect (Bonjour unavailable in App Clips)")
            alertMessage = "Kode QR tidak mengandung informasi koneksi. Minta host untuk membuat QR baru."
            showAlert = true
            return
        }

        if hasPermission {
            // If already fully permitted from a previous run, just connect
            connectDirectly()
        }
    }

    /// Called after the user taps "Izinkan Akses" on our custom sheet.
    /// We request Microphone first, then connect directly via TCP.
    func permissionGranted() {
        // Small delay to let our sheet dismiss before system dialogs appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.requestMicrophoneThenConnect()
        }
    }

    // MARK: - 1. Request Microphone Permission

    private func requestMicrophoneThenConnect() {
        print("[AppClipJoinVM] Step 1: Requesting Microphone permission...")

        // Configure audio session first
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("[AppClipJoinVM] Audio session setup error: \(error)")
        }

        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hasPermission = true
                print("[AppClipJoinVM] Mic permission granted: \(granted)")

                // Now connect directly via TCP
                self.connectDirectly()
            }
        }
    }

    // MARK: - 2. Direct TCP Connection (No Bonjour)

    /// Connect directly to the host using the IP address and port from the QR code.
    /// This bypasses Bonjour discovery entirely, which is required because App Clips
    /// cannot use NWBrowser for Bonjour service discovery.
    private func connectDirectly() {
        guard let hostIP = hostIP, let hostPort = hostPort else {
            handleFailure("Informasi koneksi tidak tersedia.")
            return
        }

        guard !isConnecting else { return }
        isConnecting = true
        connectionFailed = false

        print("[AppClipJoinVM] Step 2: Connecting directly to \(hostIP):\(hostPort)...")

        let nm = NetworkManager()
        self.networkManager = nm

        let host = NWEndpoint.Host(hostIP)
        let port = NWEndpoint.Port(rawValue: hostPort)!

        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.includePeerToPeer = true

        let connection = NWConnection(host: host, port: port, using: params)
        nm.hostConnection = connection

        var didComplete = false

        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self, !didComplete else { return }
            switch state {
            case .ready:
                didComplete = true
                print("[AppClipJoinVM] Connected to host!")
                // Send join request
                let message = NetworkMessage.joinRequest(user: self.currentUser)
                nm.sendMessage(message, on: connection)
                nm.receiveMessages(on: connection, peerID: nil)
                
                DispatchQueue.main.async {
                    self.isConnecting = false
                    let vm = MeetingViewModel(localUser: self.currentUser, networkManager: nm, asHost: false)
                    self.activeMeetingVM = vm
                    self.onJoinSuccess?()
                }
            case .failed(let error):
                didComplete = true
                print("[AppClipJoinVM] Connection failed: \(error)")
                DispatchQueue.main.async {
                    self.handleFailure("Gagal terhubung ke ruangan.")
                }
            case .waiting(let error):
                print("[AppClipJoinVM] Connection waiting: \(error)")
            case .preparing:
                print("[AppClipJoinVM] Connection preparing...")
            case .cancelled:
                print("[AppClipJoinVM] Connection cancelled")
            default:
                break
            }
        }

        connection.start(queue: .main)

        // 15s timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self, !didComplete, self.isConnecting else { return }
            didComplete = true
            print("[AppClipJoinVM] Timeout connecting to host")
            connection.cancel()
            self.handleFailure("Tidak dapat terhubung. Pastikan kamu dan host berada di jaringan WiFi yang sama.")
        }
    }

    // MARK: - Error Handling

    private func handleFailure(_ message: String) {
        isConnecting = false
        connectionFailed = true
        alertMessage = message
        showAlert = true
    }

    func reset() {
        roomCode = nil
        hostIP = nil
        hostPort = nil
        activeMeetingVM = nil
        isConnecting = false
        connectionFailed = false
        showAlert = false
        alertMessage = ""
        networkManager?.disconnectFromHost()
        networkManager = nil
    }
}

