//
//  EncryptionService.swift
//  solyn
//
//  AES-256-GCM encryption for local backup files.
//  Uses CryptoKit (built-in, no external dependencies).
//

import Foundation
import CryptoKit

struct EncryptionService {

    enum EncryptionError: LocalizedError {
        case invalidData
        case invalidPassword
        case decryptionFailed
        case invalidFileFormat

        var errorDescription: String? {
            switch self {
            case .invalidData: return "Data is invalid or corrupted."
            case .invalidPassword: return "Incorrect password."
            case .decryptionFailed: return "Failed to decrypt. Check your password."
            case .invalidFileFormat: return "This file is not a valid DailyVox encrypted backup."
            }
        }
    }

    // File format: [4-byte magic "DVX1"][32-byte salt][12-byte nonce][ciphertext+tag]
    private static let magic: [UInt8] = [0x44, 0x56, 0x58, 0x31] // "DVX1"

    /// Encrypt data with a password using AES-256-GCM
    static func encrypt(data: Data, password: String) throws -> Data {
        guard !password.isEmpty else { throw EncryptionError.invalidPassword }

        let salt = generateSalt()
        let key = deriveKey(from: password, salt: salt)
        let sealedBox = try AES.GCM.seal(data, using: key)

        guard let combined = sealedBox.combined else {
            throw EncryptionError.invalidData
        }

        // Build file: magic + salt + combined (nonce + ciphertext + tag)
        var output = Data(magic)
        output.append(salt)
        output.append(combined)
        return output
    }

    /// Decrypt data with a password
    static func decrypt(data: Data, password: String) throws -> Data {
        guard !password.isEmpty else { throw EncryptionError.invalidPassword }

        // Validate magic bytes
        let magicSize = magic.count
        let saltSize = 32
        let minSize = magicSize + saltSize + 12 + 16 // magic + salt + nonce + tag minimum

        guard data.count >= minSize else {
            throw EncryptionError.invalidFileFormat
        }

        let fileMagic = [UInt8](data.prefix(magicSize))
        guard fileMagic == magic else {
            throw EncryptionError.invalidFileFormat
        }

        let salt = data[magicSize..<(magicSize + saltSize)]
        let combined = data[(magicSize + saltSize)...]

        let key = deriveKey(from: password, salt: Data(salt))

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    // MARK: - Helpers

    private static func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private static func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            outputByteCount: 32
        )
        return derived
    }
}
