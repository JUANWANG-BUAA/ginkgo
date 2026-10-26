package cn.edu.buaa.ginkgo.ginkgo_mirror;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;

/** Host-JVM synthetic contract test. Does NOT validate Android Keystore/file APIs. */
public final class AesGcmSnapshotCipherContract {
    private interface Checked { void run() throws Exception; }
    private static void rejected(Checked action) throws Exception {
        try { action.run(); } catch (GeneralSecurityException expected) { return; }
        throw new AssertionError("malformed/tampered input was accepted");
    }
    private static SecretKey key() throws Exception {
        KeyGenerator generator = KeyGenerator.getInstance("AES");
        generator.init(256);
        return generator.generateKey();
    }
    public static void main(String[] ignored) throws Exception {
        SecretKey key = key();
        byte[] plain = "{\"fixture\":\"synthetic-learning-course\",\"rows\":[]}".getBytes(StandardCharsets.UTF_8);
        byte[] first = AesGcmSnapshotCipher.seal(key, plain);
        byte[] second = AesGcmSnapshotCipher.seal(key, plain);
        if (!Arrays.equals(plain, AesGcmSnapshotCipher.open(key, first))) throw new AssertionError("roundtrip");
        if (Arrays.equals(first, second)) throw new AssertionError("nonce reuse");
        if (new String(first, StandardCharsets.ISO_8859_1).contains("synthetic-learning-course")) throw new AssertionError("plaintext present");
        rejected(() -> AesGcmSnapshotCipher.open(key(), first));
        for (int index : new int[] {0, 3, 4, 15, 16, first.length - 1}) {
            byte[] tampered = first.clone(); tampered[index] ^= 1;
            rejected(() -> AesGcmSnapshotCipher.open(key, tampered));
        }
        rejected(() -> AesGcmSnapshotCipher.open(key, Arrays.copyOf(first, first.length - 1)));
        rejected(() -> AesGcmSnapshotCipher.open(key, new byte[0]));
        rejected(() -> AesGcmSnapshotCipher.open(key, new byte[AesGcmSnapshotCipher.MAX_BLOB_BYTES + 1]));
        rejected(() -> AesGcmSnapshotCipher.seal(key, new byte[0]));
        rejected(() -> AesGcmSnapshotCipher.seal(key, new byte[AesGcmSnapshotCipher.MAX_PLAINTEXT_BYTES + 1]));
        byte[] max = new byte[AesGcmSnapshotCipher.MAX_PLAINTEXT_BYTES];
        byte[] full = AesGcmSnapshotCipher.seal(key, max);
        if (full.length != AesGcmSnapshotCipher.MAX_BLOB_BYTES || !Arrays.equals(max, AesGcmSnapshotCipher.open(key, full))) throw new AssertionError("maximum boundary");
        System.out.println("snapshot cipher synthetic contracts passed (host JVM; not Android Keystore acceptance)");
    }
}
