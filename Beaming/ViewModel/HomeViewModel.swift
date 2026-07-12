//
//  HomeViewModel.swift
//  Beaming
//
//  Drives the Home screen: first-launch permission prompt, create/join room.
//

import Foundation
import Network
import Observation
import AVFoundation
import Speech
import UIKit

@Observable
class HomeViewModel {
    var currentUser: User

    var showPermission: Bool = false
    var showQRScanner: Bool = false
    var activeMeetingVM: MeetingViewModel?
    var navigateToMeeting: Bool = false
    var isConnecting: Bool = false
    var showAlert: Bool = false
    var alertMessage: String = ""

    // MARK: - Unified permission status (Home permission sheet)

    /// Reflects the real Apple authorization status. False (unchecked) until granted.
    var micGranted: Bool = false
    var speechGranted: Bool = false
    var cameraGranted: Bool = false

    private var pendingAction: PendingAction?
    private enum PendingAction { case create, join }

    private let permissionKey = "hasShownPermission"

    init(user: User) {
        self.currentUser = user
    }

    /// Called from HomeView.onAppear. On first launch, auto-open the permission
    /// sheet once (no pending action — purely informational + mic grant).
    func onAppear() {
        guard !UserDefaults.standard.bool(forKey: permissionKey) else { return }
        pendingAction = nil
        refreshPermissions()
        showPermission = true
    }

    // MARK: - Create / Join

    func didTapCreate() {
        if UserDefaults.standard.bool(forKey: permissionKey) {
            startHost()
        } else {
            pendingAction = .create
            refreshPermissions()
            showPermission = true
        }
    }

    func didTapJoin() {
        if UserDefaults.standard.bool(forKey: permissionKey) {
            showQRScanner = true
        } else {
            pendingAction = .join
            refreshPermissions()
            showPermission = true
        }
    }

    // MARK: - Permission

    func permissionAllowed() {
        UserDefaults.standard.set(true, forKey: permissionKey)
        showPermission = false
        let action = pendingAction
        pendingAction = nil
        switch action {
        case .create: startHost()
        case .join:   showQRScanner = true
        case .none:   break
        }
    }

    func cancelFlow() {
        showPermission = false
        pendingAction = nil
    }

    /// Open the permission checklist from the Home settings button — no pending
    /// create/join action, purely to review or grant permissions.
    func openPermissionSheet() {
        pendingAction = nil
        refreshPermissions()
        showPermission = true
    }

    // MARK: - Permission status

    /// Read the current authorization status for each permission so already-granted
    /// ones appear checked when the sheet opens (and un-granted ones stay unchecked).
    func refreshPermissions() {
        micGranted = AVAudioApplication.shared.recordPermission == .granted
        speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// Tap a permission row. If iOS hasn't decided yet, fire the real Apple prompt
    /// and set the matching flag only if the user allows it. Once the user has
    /// *denied*, Apple will never show the prompt again — so in that case we deep-link
    /// to the app's Settings page (the only way to re-enable). `refreshPermissions()`
    /// (called on scenePhase → active) re-reads the status when the user returns, so
    /// the checkmark updates and the row stays usable.
    func requestPermission(_ kind: PermissionKind) {
        switch kind {
        case .microphone:
            let status = AVAudioApplication.shared.recordPermission
            if status == .undetermined {
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async { self.micGranted = granted }
                }
            } else if status != .granted {
                openAppSettings()
            }
        case .speech:
            let status = SFSpeechRecognizer.authorizationStatus()
            if status == .notDetermined {
                SFSpeechRecognizer.requestAuthorization { st in
                    DispatchQueue.main.async { self.speechGranted = (st == .authorized) }
                }
            } else if status != .authorized {
                openAppSettings()
            }
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            if status == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async { self.cameraGranted = granted }
                }
            } else if status != .authorized {
                openAppSettings()
            }
        }
    }

    /// Apple records a single per-permission decision; after a denial the request
    /// APIs just return denied silently. Sending the user to Settings is the only way
    /// back, so that's what a denied row does on re-tap.
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Host / Guest session

    private func startHost() {
        let nm = NetworkManager()
        let vm = MeetingViewModel(localUser: currentUser, networkManager: nm, asHost: true)
        activeMeetingVM = vm
        navigateToMeeting = true
    }

    /// The scanned QR encodes the host's Bonjour service name ("hostName::::roomID").
    func joinWithCode(_ code: String) {
        showQRScanner = false
        let nm = NetworkManager()
        let endpoint = NWEndpoint.service(name: code, type: "_beaming._tcp", domain: "local.", interface: nil)

        isConnecting = true
        var didComplete = false

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, !didComplete else { return }
            didComplete = true
            self.isConnecting = false
            self.alertMessage = "Tidak dapat terhubung. Pastikan kamu dekat dengan host."
            self.showAlert = true
            nm.disconnectFromHost()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)

        nm.connectToHost(endpoint: endpoint, localUser: currentUser) { [weak self] success in
            guard let self, !didComplete else { return }
            didComplete = true
            timeout.cancel()
            self.isConnecting = false
            if success {
                let vm = MeetingViewModel(localUser: self.currentUser, networkManager: nm, asHost: false)
                self.activeMeetingVM = vm
                self.navigateToMeeting = true
            } else {
                self.alertMessage = "Gagal terhubung ke ruangan."
                self.showAlert = true
            }
        }
    }

    func resetAfterMeeting() {
        activeMeetingVM = nil
        navigateToMeeting = false
    }
}

/// Permissions unified in the Home permission sheet.
enum PermissionKind {
    case microphone, speech, camera
}
