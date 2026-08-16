package com.dailyvox.app.security

import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * AES-256-GCM backup, keyed from a PASSPHRASE — byte-for-byte the iOS container.
 *
 *   [4-byte magic "DVX1"][32-byte salt][12-byte nonce][ciphertext + 16-byte tag]
 *
 * The first version of this file keyed from the Android Keystore, and it was
 * broken in a way that only shows up on the day it matters. Keystore entries are
 * bound to the app's UID and are destroyed when app data is cleared or the app
 * is uninstalled — so the backup could be restored to the same install and
 * nowhere else. Reinstall, factory reset, new phone: every real restore scenario
 * produced an unreadable file. It was tested by wiping app data and importing
 * the backup, which silently added nothing.
 *
 * It also carried a comment claiming the container matched iOS. It did not:
 * iOS writes a 32-byte salt that the Keystore version had no use for and did not
 * emit, so an iPhone backup and an Android backup could never have been read by
 * the other platform. That comment was wrong and this file now earns it.
 *
 * Key derivation is HKDF-SHA256 over the passphrase with the file's salt, which
 * is what `EncryptionService.deriveKey` does on iOS. HKDF is an EXPANSION
 * function, not a password-hardening one — it does no stretching, so a weak
 * passphrase is weakly protected. That is a real limitation, kept deliberately:
 * matching iOS byte-for-byte is worth more than unilaterally hardening one
 * platform and splitting the format in two. The UI asks for a long passphrase
 * for that reason, and moving both platforms to Argon2id is the right fix.
 */
object Vault {

    private val MAGIC = byteArrayOf(0x44, 0x56, 0x58, 0x31)   // "DVX1"
    private const val SALT_BYTES = 32
    private const val NONCE_BYTES = 12
    private const val TAG_BITS = 128

    class WrongPassphrase : Exception("Wrong passphrase, or this is not a DailyVox backup.")
    class NotABackup : Exception("This file is not a DailyVox backup.")

    fun encrypt(plaintext: String, passphrase: String): ByteArray {
        require(passphrase.isNotEmpty()) { "passphrase required" }
        val salt = ByteArray(SALT_BYTES).also { SecureRandom().nextBytes(it) }
        val nonce = ByteArray(NONCE_BYTES).also { SecureRandom().nextBytes(it) }

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.ENCRYPT_MODE,
            SecretKeySpec(deriveKey(passphrase, salt), "AES"),
            GCMParameterSpec(TAG_BITS, nonce),
        )
        val body = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        // CryptoKit's `combined` is nonce + ciphertext + tag, so the nonce goes
        // inside that block rather than before the salt.
        return MAGIC + salt + nonce + body
    }

    fun decrypt(bytes: ByteArray, passphrase: String): String {
        val minimum = MAGIC.size + SALT_BYTES + NONCE_BYTES + 16
        if (bytes.size < minimum) throw NotABackup()
        if (!bytes.copyOfRange(0, MAGIC.size).contentEquals(MAGIC)) throw NotABackup()

        val salt = bytes.copyOfRange(MAGIC.size, MAGIC.size + SALT_BYTES)
        val nonce = bytes.copyOfRange(MAGIC.size + SALT_BYTES, MAGIC.size + SALT_BYTES + NONCE_BYTES)
        val body = bytes.copyOfRange(MAGIC.size + SALT_BYTES + NONCE_BYTES, bytes.size)

        return try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                SecretKeySpec(deriveKey(passphrase, salt), "AES"),
                GCMParameterSpec(TAG_BITS, nonce),
            )
            String(cipher.doFinal(body), Charsets.UTF_8)
        } catch (_: Exception) {
            // GCM authentication failure is indistinguishable from a wrong
            // passphrase by design, and saying "corrupt file" would send someone
            // hunting a problem that does not exist.
            throw WrongPassphrase()
        }
    }

    /**
     * HKDF-SHA256, extract-then-expand (RFC 5869), matching CryptoKit's
     * `HKDF<SHA256>.deriveKey(inputKeyMaterial:salt:outputByteCount:)`.
     * CryptoKit passes no `info`, so neither does this.
     */
    private fun deriveKey(passphrase: String, salt: ByteArray): ByteArray {
        val hmac = Mac.getInstance("HmacSHA256")

        // Extract
        hmac.init(SecretKeySpec(salt, "HmacSHA256"))
        val prk = hmac.doFinal(passphrase.toByteArray(Charsets.UTF_8))

        // Expand — one 32-byte block, so a single round with counter 0x01.
        hmac.init(SecretKeySpec(prk, "HmacSHA256"))
        hmac.update(byteArrayOf(0x01))
        return hmac.doFinal()
    }
}
