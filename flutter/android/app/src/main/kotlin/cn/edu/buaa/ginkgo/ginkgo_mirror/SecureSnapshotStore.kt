package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/** Optional learning snapshot blob only. Wired through explicit consent; disabled by default.
 *
 * Caller must hold its account/session-generation/epoch lock through save/clear,
 * validate SnapshotBook after load, and obtain explicit opt-in. A file contains
 * ciphertext only; no account hash, query or fetched-at appears in its name.
 * A new Keystore alias deliberately does not access the credential vault.
 * noBackupFilesDir excludes ciphertext from Android Auto Backup/device transfer.
 * Public methods throw generic errors; they never log the exception or content.
 *
 * Security review + Android-device Keystore validation are required before use.
 */
class SecureSnapshotStore(context: Context) {
    // Android may expose its own private directory through /data/user/0 -> /data/data.
    // Resolve that trusted framework-owned parent, then reject symlinks in our child store.
    private val root = File(context.applicationContext.noBackupFilesDir.canonicalFile, "ginkgo-learning-snapshots-v1")
    private val lock = STORE_LOCK

    /** Load does not create a key or file. Missing key with an existing blob is
     * an unavailable/corrupt store, not a confirmed empty snapshot. */
    fun load(): ByteArray? = synchronized(lock) {
        try {
            if (!root.exists() && !isSymlink(root)) return@synchronized null
            val atomic = checkedFile(createDirectory = false)
            if (!atomic.baseFile.exists() && !File(root, "learning-v1.blob.bak").exists()) return@synchronized null
            val secret = key(create = false) ?: throw IOException("snapshot key unavailable")
            val encrypted = atomic.openRead().use { input -> readBounded(input) }
            AesGcmSnapshotCipher.open(secret, encrypted)
        } catch (_: Exception) {
            throw IOException("安全快照不可读取，请清除该快照后重试")
        }
    }

    /** Returns only after a durable encrypted AtomicFile commit. No plaintext
     * temporary files are used. Failed encryption leaves the old blob intact. */
    fun save(envelope: ByteArray) = synchronized(lock) {
        try {
            val encrypted = AesGcmSnapshotCipher.seal(key(create = true)!!, envelope)
            val atomic = checkedFile(createDirectory = true)
            var stream: java.io.FileOutputStream? = null
            try {
                stream = atomic.startWrite()
                stream.write(encrypted)
                stream.fd.sync()
                atomic.finishWrite(stream)
            } catch (_: Exception) {
                stream?.let { atomic.failWrite(it) }
                throw IOException("snapshot write unavailable")
            }
        } catch (_: Exception) {
            throw IOException("安全快照未保存，旧快照未被新数据替代")
        }
    }

    /** Deletes exactly this store's blob/backup/temporary file. Never visits
     * credentials, tasks or arbitrary user-selected files. Disable/exit must
     * call this synchronously before publishing the next session scope. */
    fun clear() = synchronized(lock) {
        try {
            if (!root.exists() && !isSymlink(root)) return@synchronized
            val atomic = checkedFile(createDirectory = false)
            atomic.delete()
            if (listOf("learning-v1.blob", "learning-v1.blob.bak", "learning-v1.blob.new")
                    .any { File(root, it).exists() }) {
                throw IOException("snapshot erase unavailable")
            }
        } catch (_: Exception) {
            throw IOException("安全快照清除失败，请保持离线快照功能关闭")
        }
    }

    private fun checkedFile(createDirectory: Boolean): AtomicFile {
        if (isSymlink(root)) throw IOException("snapshot directory rejected")
        if (createDirectory && !root.exists() && !root.mkdir()) throw IOException("snapshot directory unavailable")
        if (!root.isDirectory || root.canonicalFile != root.absoluteFile) throw IOException("snapshot directory rejected")
        for (name in listOf("learning-v1.blob", "learning-v1.blob.bak", "learning-v1.blob.new")) {
            val file = File(root, name)
            if (isSymlink(file) || (file.exists() && !file.isFile)) throw IOException("snapshot file rejected")
        }
        return AtomicFile(File(root, "learning-v1.blob"))
    }

    private fun isSymlink(file: File): Boolean = try {
        OsConstants.S_ISLNK(Os.lstat(file.absolutePath).st_mode)
    } catch (error: ErrnoException) {
        if (error.errno == OsConstants.ENOENT) false else throw IOException("snapshot path unavailable")
    }

    private fun readBounded(input: FileInputStream): ByteArray {
        val size = input.channel.size()
        if (size <= 0 || size > AesGcmSnapshotCipher.MAX_BLOB_BYTES) throw IOException("snapshot size rejected")
        val bytes = ByteArray(size.toInt())
        var offset = 0
        while (offset < bytes.size) {
            val count = input.read(bytes, offset, bytes.size - offset)
            if (count <= 0) throw IOException("snapshot size changed")
            offset += count
        }
        if (input.read() != -1) throw IOException("snapshot size changed")
        return bytes
    }

    private fun key(create: Boolean): SecretKey? {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        if (!create) return null
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .setUserAuthenticationRequired(false)
            .build())
        return generator.generateKey()
    }

    companion object {
        private const val KEY_ALIAS = "ginkgo_learning_snapshots_aes_v1"
        private val STORE_LOCK = Any()
    }
}
