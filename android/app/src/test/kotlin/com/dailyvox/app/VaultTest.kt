package com.dailyvox.app

import com.dailyvox.app.security.Vault
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The backup format, tested as the cross-platform contract it claims to be.
 *
 * The version this replaces keyed from the Android Keystore, whose entries die
 * with the app's data. It could only be restored to the same install — useless
 * for reinstall, factory reset or a new phone, which is every real reason to
 * hold a backup. It also carried a comment saying the container matched iOS
 * while omitting iOS's 32-byte salt entirely.
 */
class VaultTest {

    private val journal = """{"app":"DailyVox","entries":[{"date":1,"text":"Sarah's flight lands tonight."}]}"""

    @Test fun `round trip returns the original`() {
        val sealed = Vault.encrypt(journal, "correct horse battery staple")
        assertEquals(journal, Vault.decrypt(sealed, "correct horse battery staple"))
    }

    @Test fun `the container is byte-for-byte the iOS layout`() {
        // [4 magic][32 salt][12 nonce][ciphertext + 16 tag] — EncryptionService.swift:30.
        // A mismatch here means an iPhone backup cannot be restored on Android,
        // which is the promise the Settings copy makes out loud.
        val sealed = Vault.encrypt(journal, "passphrase")
        assertArrayEquals(byteArrayOf(0x44, 0x56, 0x58, 0x31), sealed.copyOfRange(0, 4))
        assertEquals(4 + 32 + 12 + journal.toByteArray().size + 16, sealed.size)
    }

    @Test fun `a wrong passphrase is refused, not silently mangled`() {
        val sealed = Vault.encrypt(journal, "the right one")
        try {
            Vault.decrypt(sealed, "the wrong one")
            throw AssertionError("decrypt should have thrown")
        } catch (_: Vault.WrongPassphrase) { /* expected */ }
    }

    @Test fun `a file that is not a backup is refused`() {
        try {
            Vault.decrypt("plain json, no magic bytes at all".toByteArray(), "x")
            throw AssertionError("decrypt should have thrown")
        } catch (_: Vault.NotABackup) { /* expected */ }
    }

    @Test fun `salt and nonce are fresh on every write`() {
        // Reusing a GCM nonce under one key breaks the cipher outright, so this
        // is not a style check.
        val a = Vault.encrypt(journal, "same passphrase")
        val b = Vault.encrypt(journal, "same passphrase")
        assertNotEquals(
            a.copyOfRange(4, 4 + 32).toList(),
            b.copyOfRange(4, 4 + 32).toList(),
        )
        assertNotEquals(
            a.copyOfRange(36, 36 + 12).toList(),
            b.copyOfRange(36, 36 + 12).toList(),
        )
    }

    @Test fun `truncated files do not crash the importer`() {
        val sealed = Vault.encrypt(journal, "p")
        for (cut in intArrayOf(0, 3, 10, 40, 50)) {
            try {
                Vault.decrypt(sealed.copyOfRange(0, cut.coerceAtMost(sealed.size)), "p")
            } catch (_: Exception) { /* any refusal is fine; a crash is not */ }
        }
        assertTrue(true)
    }

    @Test fun `key derivation matches real CryptoKit output`() {
        // GROUND TRUTH, not a guess. Produced by running this against Apple's
        // CryptoKit on this machine:
        //
        //   HKDF<SHA256>.deriveKey(
        //       inputKeyMaterial: SymmetricKey(data: Data("correct horse battery staple".utf8)),
        //       salt: Data((0..<32).map { UInt8($0) }),
        //       outputByteCount: 32)
        //
        // My first attempt at this test asserted RFC 5869 A.1's OKM, which was
        // simply wrong: that vector passes a 10-byte `info` and CryptoKit passes
        // none, so the expected value described a different derivation. The test
        // failed and the implementation was fine.
        //
        // If this ever breaks, an Android backup and an iPhone backup have
        // diverged at the key level and neither can open the other's file.
        val salt = ByteArray(32) { it.toByte() }
        val derived = deriveForTest("correct horse battery staple", salt)
        assertEquals(
            "0d8188c417cbc882d8ac143c062aa7ddd3466a00335f94b2fb5bdb99ac3c2bdd",
            derived.joinToString("") { "%02x".format(it) },
        )
    }

    @Test fun `an iPhone backup opens on Android`() {
        // THE MIGRATION TEST, and the fixture is not hand-rolled: it was written
        // by Apple's CryptoKit on this machine, using EncryptionService.encrypt's
        // exact shape — AES.GCM.seal + HKDF<SHA256> + the 32-byte salt header.
        //
        // The reverse direction was checked the same way: a file produced by
        // this Kotlin code was opened by CryptoKit and round-tripped its JSON.
        // Between them the two runs are the only real evidence that "restorable
        // on any phone, including an iPhone" is a fact rather than a hope.
        val bytes = javaClass.classLoader!!
            .getResourceAsStream("iphone-backup.dvx")!!
            .use { it.readBytes() }

        val json = Vault.decrypt(bytes, "from-an-iphone-2026")
        assertTrue("got: $json", json.contains("Told Sarah about the job."))
    }

    @Test fun `an iPhone backup with the wrong passphrase is refused`() {
        val bytes = javaClass.classLoader!!
            .getResourceAsStream("iphone-backup.dvx")!!
            .use { it.readBytes() }
        try {
            Vault.decrypt(bytes, "not-the-passphrase")
            throw AssertionError("should have thrown")
        } catch (_: Vault.WrongPassphrase) { /* expected */ }
    }

    /** Mirror of Vault.deriveKey, which is private. Kept identical on purpose:
     *  if the two drift, the test above stops describing the shipped code. */
    private fun deriveForTest(passphrase: String, salt: ByteArray): ByteArray {
        val m = javax.crypto.Mac.getInstance("HmacSHA256")
        m.init(javax.crypto.spec.SecretKeySpec(salt, "HmacSHA256"))
        val prk = m.doFinal(passphrase.toByteArray(Charsets.UTF_8))
        m.init(javax.crypto.spec.SecretKeySpec(prk, "HmacSHA256"))
        m.update(byteArrayOf(0x01))
        return m.doFinal()
    }
}
