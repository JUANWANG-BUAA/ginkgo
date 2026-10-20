package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Load the Rust library from the JVM before Flutter's Dart FFI does, so
        // JNI_OnLoad can cache the app class loader's CredentialVault class.
        try {
            System.loadLibrary("ginkgo_flutter_bridge")
            CredentialVault.initialize(applicationContext)
        } catch (t: Throwable) {
            Log.e("Ginkgo", "credential vault initialization failed")
        }
        super.onCreate(savedInstanceState)
    }
}
