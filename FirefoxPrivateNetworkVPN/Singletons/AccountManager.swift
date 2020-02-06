//
//  AccountManager
//  FirefoxPrivateNetworkVPN
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2019 Mozilla Corporation.
//

import Foundation
import RxSwift

class AccountManager: AccountManaging, Navigating {
    static var navigableItem: NavigableItem = .account

    private(set) var account: Account?
    private(set) var availableServers: [VPNCountry]?
    private(set) var heartbeatFailedEvent = PublishSubject<Void>()
    private var heartbeatTimer: DispatchSourceTimer?

    static let sharedManager = AccountManager()

    func login(with verification: VerifyResponse, completion: @escaping (Result<Void, Error>) -> Void) {
        Credentials.removeAll()
        let credentials = Credentials(with: verification)
        let account = Account(credentials: credentials, user: verification.user)

        let dispatchGroup = DispatchGroup()
        var addDeviceError: Error?
        var retrieveServersError: Error?

        dispatchGroup.enter()
        account.addCurrentDevice { result in
            if case .failure(let error) = result {
                addDeviceError = error
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        retrieveVPNServers(with: account.token) { result in
            if case .failure(let error) = result {
                retrieveServersError = error
            }
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            switch (addDeviceError, retrieveServersError) {
            case (.none, .none):
                credentials.saveAll()
                self.account = account
                self.startHeartbeat()
                completion(.success(()))
            case (.some(let error), _):
                if let error = error as? GuardianAPIError, error == GuardianAPIError.maxDevicesReached {
                    credentials.saveAll()
                    self.account = account
                    self.startHeartbeat()
                }
                completion(.failure(error))
            case (.none, .some(let error)):
                if let device = account.currentDevice {
                    account.removeDevice(with: device.publicKey) { _ in }
                }
                completion(.failure(error))
            }
        }
    }

    func loginWithStoredCredentials(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let credentials = Credentials.fetchAll(), let currentDevice = Device.fetchFromUserDefaults() else {
            completion(.failure(GuardianError.needToLogin))
            return
        }

        let account = Account(credentials: credentials, currentDevice: currentDevice)

        let dispatchGroup = DispatchGroup()
        var setUserError: Error?
        var retrieveServersError: Error?

        dispatchGroup.enter()
        account.getUser { result in
            if case .failure(let error) = result {
                setUserError = error
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        retrieveVPNServers(with: account.token) { result in
            if case .failure(let error) = result {
                retrieveServersError = error
            }
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            switch (setUserError, retrieveServersError) {
            case (.none, .none):
                credentials.saveAll()
                self.account = account
                self.startHeartbeat()
                completion(.success(()))
            case (let userError, let serverError):
                let error = userError ?? serverError
                completion(.failure(error ?? GuardianAPIError.unknown))
            }
        }
    }

    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let device = account?.currentDevice, let token = account?.token else {
            completion(Result.failure(GuardianError.needToLogin))
            return
        }
        GuardianAPI.removeDevice(with: token, deviceKey: device.publicKey) { result in
            switch result {
            case .success:
                self.resetAccount()
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func retrieveVPNServers(with token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        GuardianAPI.availableServers(with: token) { result in
            switch result {
            case .success (let servers):
                self.availableServers = servers
                self.availableServers?.saveToUserDefaults()
                if !VPNCity.existsInDefaults, let randomUSServer = servers.first(where: { $0.code.uppercased() == "US" })?.cities.randomElement() {
                    randomUSServer.saveToUserDefaults()
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func resetAccount() {
        stopHeartbeat()
        DependencyFactory.sharedFactory.tunnelManager.stopAndRemove()
        Credentials.removeAll()
        Device.removeFromUserDefaults()
        account = nil
        availableServers = nil
    }

    func startHeartbeat() {
        heartbeatTimer = DispatchSource.makeTimerSource()
        heartbeatTimer?.schedule(deadline: .now(), repeating: .seconds(3600), leeway: .seconds(1))
        heartbeatTimer?.setEventHandler { [weak self] in
            self?.pollUser()
        }
        heartbeatTimer?.activate()
    }

    func stopHeartbeat() {
        heartbeatTimer = nil
    }

    private func pollUser() {
        guard let account = account else { return }
        account.getUser { result in
            guard case .failure(let error) = result,
                let subscriptionError = error as? GuardianAPIError,
                subscriptionError.isAuthError else { return }

            DispatchQueue.main.async {
                self.resetAccount()
                self.navigate(to: .landing)
            }
        }
    }
}
