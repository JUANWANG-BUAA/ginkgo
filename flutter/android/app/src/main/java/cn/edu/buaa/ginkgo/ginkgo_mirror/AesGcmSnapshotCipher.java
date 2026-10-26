package cn.edu.buaa.ginkgo.ginkgo_mirror;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Exact bounded secure-blob wire codec. Key selection belongs to Android Keystore.
 * Not a credential codec. No target files, account identifiers or diagnostics.
 */
public final class AesGcmSnapshotCipher {
    public static final int MAX_PLAINTEXT_BYTES = 512 * 1024;
    public static final int MAX_BLOB_BYTES = MAX_PLAINTEXT_BYTES + 32;
    private static final int IV_BYTES = 12;
    private static final byte[] MAGIC = new byte[] {'G', 'S', 'B', 1};
    private static final byte[] AAD = "cn.edu.buaa.ginkgo/snapshot/learning-v1".getBytes(StandardCharsets.UTF_8);
    private AesGcmSnapshotCipher() {}

    public static byte[] seal(SecretKey key, byte[] plaintext) throws GeneralSecurityException {
        if (plaintext == null || plaintext.length == 0 || plaintext.length > MAX_PLAINTEXT_BYTES) {
            throw new GeneralSecurityException("snapshot input rejected");
        }
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, key);
        byte[] iv = cipher.getIV();
        if (iv.length != IV_BYTES) throw new GeneralSecurityException("snapshot cipher unavailable");
        cipher.updateAAD(AAD);
        byte[] encrypted = cipher.doFinal(plaintext);
        byte[] blob = new byte[MAGIC.length + IV_BYTES + encrypted.length];
        System.arraycopy(MAGIC, 0, blob, 0, MAGIC.length);
        System.arraycopy(iv, 0, blob, MAGIC.length, IV_BYTES);
        System.arraycopy(encrypted, 0, blob, MAGIC.length + IV_BYTES, encrypted.length);
        return blob;
    }

    public static byte[] open(SecretKey key, byte[] blob) throws GeneralSecurityException {
        if (blob == null || blob.length <= 32 || blob.length > MAX_BLOB_BYTES ||
                !Arrays.equals(Arrays.copyOfRange(blob, 0, MAGIC.length), MAGIC)) {
            throw new GeneralSecurityException("snapshot blob rejected");
        }
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, key,
            new GCMParameterSpec(128, Arrays.copyOfRange(blob, MAGIC.length, MAGIC.length + IV_BYTES)));
        cipher.updateAAD(AAD);
        return cipher.doFinal(blob, MAGIC.length + IV_BYTES, blob.length - MAGIC.length - IV_BYTES);
    }
}
