//
//  AppLockManager.swift
//  solyn
//
//  Manages app lock functionality using device biometrics (Face ID/Touch ID)
//  or device passcode. Uses Apple's LocalAuthentication framework.
//
//  Security: Authentication is handled entirely by iOS - no credentials stored in app.
//

import Foundation
import LocalAuthentication

/// Manages app lock state and biometric/passcode authentication.
/// Uses iOS LocalAuthentication framework - no sensitive data stored by the app.
final class AppLockManager: ObservableObject {
    
    // MARK: - Shared Instance
    
    static let shared = AppLockManager()

    // MARK: - Private Properties
    
    private let defaults = UserDefaults.standard
    private let isEnabledKey = "appLockEnabled"

    // MARK: - Published Properties
    
    /// Whether app lock is enabled by the user
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: isEnabledKey) }
    }

    /// Current unlock state - resets to false when app goes to background
    @Published var isUnlocked: Bool = false

    // MARK: - Initialization
    
    private init() {
        self.isEnabled = defaults.bool(forKey: isEnabledKey)
    }
    
    // MARK: - Biometrics Availability

    /// Returns true if biometrics (Face ID / Touch ID) are available on this device.
    var biometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Returns the biometry type name for display (Face ID, Touch ID, or Passcode).
    var biometryTypeName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Passcode"
        @unknown default: return "Passcode"
        }
    }

    /// Authenticate the user using Face ID / Touch ID, with passcode as fallback.
    func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        let reason = "Unlock DailyVox to access your diary."

        // Check if biometrics are available
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // Use biometrics (Face ID / Touch ID)
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                        completion(true)
                    } else if let error = authError as? LAError, error.code == .userFallback {
                        // User tapped "Enter Password" - fall back to passcode
                        self.authenticateWithPasscode(completion: completion)
                    } else {
                        // Biometrics failed - try passcode
                        self.authenticateWithPasscode(completion: completion)
                    }
                }
            }
        } else {
            // Biometrics not available, use passcode
            authenticateWithPasscode(completion: completion)
        }
    }

    private func authenticateWithPasscode(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        let reason = "Enter your passcode to unlock DailyVox."

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                self.isUnlocked = success
                completion(success)
            }
        }
    }

    /// Lock the app again (e.g., when going to background).
    /// Called automatically when app enters background.
    func lock() {
        isUnlocked = false
    }
}

// MARK: - Security Notes
//
// This implementation uses Apple's LocalAuthentication framework which:
// - Never exposes biometric data to the app
// - Handles all authentication securely in the Secure Enclave
// - Falls back to device passcode when biometrics fail
// - Does not store any credentials in the app
