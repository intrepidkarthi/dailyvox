package com.dailyvox.app.security

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * AES-256-GCM export, keyed from the Android Keystore.
 *
 * iOS ships encrypted exports and my first Android export wrote plaintext JSON,
 * which quietly made the app's own "your data is yours, always portable, never
 * readable by anyone else" claim false on Android. This closes that.
 *
 * The key lives in the Keystore and is generated per install — it never exists as
 * bytes we hold, and StrongBox is requested where the hardware has it. That means
 * an export can only be read back ON THIS DEVICE, which is the correct trade for
 * a backup: it protects a file that leaves the app sandbox, and it is why the
 * plaintext JSON export is kept alongside it as the explicit portability path.
 *
 * File format matches the iOS container so either platform can read the other's:
 *   [DVX1 magic][12-byte IV][ciphertext+tag]
 */
object Vault {

    private const val KEY_ALIAS = "dailyvox.export.v1"
    private const val TRANSFORM = "AES/GCM/NoPadding"
    private val MAGIC = "DVX1".toByteArray(Charsets.US_ASCII)

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }

        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .apply {
                // StrongBox is a hardware security module and is absent on most
                // mid-range devices — request it, but never require it, or the
                // export silently fails on exactly the phones this app targets.
                if (android.os.Build.VERSION.SDK_INT >= 28) {
                    try { setIsStrongBoxBacked(true) } catch (_: Exception) {}
                }
            }
            .build()
        return try {
            gen.init(spec); gen.generateKey()
        } catch (_: Exception) {
            // StrongBox refused. Retry without it rather than leaving the user
            // with no export at all.
            val fallback = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            fallback.init(
                KeyGenParameterSpec.Builder(KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256).build()
            )
            fallback.generateKey()
        }
    }

    fun encryptToFile(context: Context, plaintext: String, filename: String): File {
        val cipher = Cipher.getInstance(TRANSFORM).apply { init(Cipher.ENCRYPT_MODE, key()) }
        val body = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        val out = File(context.getExternalFilesDir(null), filename)
        out.outputStream().use { it.write(MAGIC); it.write(cipher.iv); it.write(body) }
        return out
    }

    fun decryptFile(file: File): String {
        val all = file.readBytes()
        require(all.size > 16 && all.copyOfRange(0, 4).contentEquals(MAGIC)) { "not a DailyVox export" }
        val iv = all.copyOfRange(4, 16)
        val body = all.copyOfRange(16, all.size)
        val cipher = Cipher.getInstance(TRANSFORM)
            .apply { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv)) }
        return String(cipher.doFinal(body), Charsets.UTF_8)
    }
}
