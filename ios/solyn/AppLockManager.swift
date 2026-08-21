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
    /// Why an unlock attempt ended.
    ///
    /// A Bool could not tell "you are not who you say you are" apart from "you
    /// pressed Cancel", and the lock screen was reporting both as
    /// "Authentication failed. Please try again." Telling someone their face was
    /// rejected when they simply dismissed the sheet is alarming on any app and
    /// worse on one whose entire pitch is that it guards a diary.
    enum Outcome {
        case success
        /// The user dismissed the sheet, tapped Cancel, or the system pulled it
        /// away. Nothing failed; nothing was attempted.
        case cancelled
        /// A genuine mismatch, lockout, or unavailable biometry.
        case failed
    }

    func authenticate(completion: @escaping (Outcome) -> Void) {
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
                        completion(.success)
                        return
                    }

                    let code = (authError as? LAError)?.code
                    switch code {
                    case .userFallback:
                        // "Enter Password" — an escalation, not a refusal.
                        self.authenticateWithPasscode(completion: completion)
                    case .userCancel, .systemCancel, .appCancel:
                        // Deliberately NOT escalated to passcode. Someone who
                        // dismissed Face ID does not want a passcode sheet
                        // thrown at them next; they want the screen to wait.
                        completion(.cancelled)
                    default:
                        // A real mismatch or lockout. Passcode is the way out.
                        self.authenticateWithPasscode(completion: completion)
                    }
                }
            }
        } else {
            // Biometrics not available, use passcode
            authenticateWithPasscode(completion: completion)
        }
    }

    private func authenticateWithPasscode(completion: @escaping (Outcome) -> Void) {
        let context = LAContext()
        let reason = "Enter your passcode to unlock DailyVox."

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                self.isUnlocked = success
                if success {
                    completion(.success)
                    return
                }
                let code = (authError as? LAError)?.code
                let cancelled = code == .userCancel || code == .systemCancel || code == .appCancel
                completion(cancelled ? .cancelled : .failed)
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
