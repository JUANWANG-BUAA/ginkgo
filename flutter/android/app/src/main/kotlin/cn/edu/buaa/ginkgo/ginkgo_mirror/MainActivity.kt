package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var settingsHandler: SystemSettingsHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.edu.buaa.ginkgo/update")
            .setMethodCallHandler(UpdateInstaller(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.edu.buaa.ginkgo/reminders")
            .setMethodCallHandler(ReminderScheduler(applicationContext))
        settingsHandler = SystemSettingsHandler(this).also {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.edu.buaa.ginkgo/system")
                .setMethodCallHandler(it)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (settingsHandler?.onPermissionResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

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
