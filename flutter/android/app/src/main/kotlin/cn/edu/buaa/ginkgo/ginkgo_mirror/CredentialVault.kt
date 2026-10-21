package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import org.json.JSONArray
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Android Keystore-backed credential vault.
 *
 * Rust owns the session and calls these static methods through JNI. Ciphertext
 * lives in private SharedPreferences; the AES-GCM key never leaves the Android
 * Keystore. Account names are hashed for preference keys, and the account is
 * stored inside the encrypted payload.
 */
object CredentialVault {
    private const val TAG = "GinkgoVault"
    private const val PREFS = "ginkgo_secure_credentials"
    private const val KEY_ALIAS = "ginkgo_credentials_aes_v1"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val PROVIDER = "AndroidKeyStore"
    private const val IV_BYTES = 12
    private const val TAG_BITS = 128

    private var appContext: Context? = null

    @JvmStatic
    fun initialize(context: Context) {
        appContext = context.applicationContext
        try {
            key()
        } catch (t: Throwable) {
            Log.e(TAG, "Android Keystore initialization failed")
        }
    }

    @JvmStatic
    fun save(account: String, payload: String): Boolean = try {
        val context = appContext ?: return false
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val iv = cipher.iv
        if (iv.size != IV_BYTES) return false
        val ciphertext = cipher.doFinal("$account\n$payload".toByteArray(Charsets.UTF_8))
        val blob = Base64.encodeToString(iv + ciphertext, Base64.NO_WRAP)
        prefs(context).edit().putString(hash(account), blob).commit()
    } catch (t: Throwable) {
        Log.e(TAG, "credential save failed")
        false
    }

    @JvmStatic
    fun load(account: String): String? = try {
        val context = appContext ?: return null
        val blob = prefs(context).getString(hash(account), null) ?: return null
        val plaintext = decrypt(blob) ?: return null
        val separator = plaintext.indexOf('\n')
        if (separator <= 0) return null
        if (plaintext.substring(0, separator) != account) return null
        plaintext.substring(separator + 1)
    } catch (t: Throwable) {
        Log.e(TAG, "credential load failed")
        null
    }

    @JvmStatic
    fun delete(account: String): Boolean = try {
        val context = appContext ?: return false
        prefs(context).edit().remove(hash(account)).commit()
    } catch (t: Throwable) {
        Log.e(TAG, "credential delete failed")
        false
    }

    @JvmStatic
    fun accounts(): String? = try {
        val context = appContext ?: return null
        val names = JSONArray()
        for (value in prefs(context).all.values) {
            val blob = value as? String ?: continue
            val plaintext = decrypt(blob) ?: continue
            val separator = plaintext.indexOf('\n')
            if (separator > 0) names.put(plaintext.substring(0, separator))
        }
        names.toString()
    } catch (t: Throwable) {
        Log.e(TAG, "credential listing failed")
        null
    }

    @JvmStatic
    fun clear(): Boolean = try {
        val context = appContext ?: return false
        prefs(context).edit().clear().commit()
    } catch (t: Throwable) {
        Log.e(TAG, "credential clear failed")
        false
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    private fun key(): SecretKey {
        val store = KeyStore.getInstance(PROVIDER).apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, PROVIDER)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(false)
                .build(),
        )
        return generator.generateKey()
    }

    private fun decrypt(blob: String): String? {
        val bytes = Base64.decode(blob, Base64.NO_WRAP)
        if (bytes.size <= IV_BYTES) return null
        val iv = bytes.copyOfRange(0, IV_BYTES)
        val ciphertext = bytes.copyOfRange(IV_BYTES, bytes.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_BITS, iv))
        return String(cipher.doFinal(ciphertext), Charsets.UTF_8)
    }

    private fun hash(account: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(account.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }
}
