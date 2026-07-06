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
        showPermission = true
    }

    // MARK: - Create / Join

    func didTapCreate() {
        if UserDefaults.standard.bool(forKey: permissionKey) {
            startHost()
        } else {
            pendingAction = .create
            showPermission = true
        }
    }

    func didTapJoin() {
        if UserDefaults.standard.bool(forKey: permissionKey) {
            showQRScanner = true
        } else {
            pendingAction = .join
            showPermission = true
        }
    }

    // MARK: - Permission

    func permissionAllowed() {
        AVAudioApplication.requestRecordPermission { _ in }
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
