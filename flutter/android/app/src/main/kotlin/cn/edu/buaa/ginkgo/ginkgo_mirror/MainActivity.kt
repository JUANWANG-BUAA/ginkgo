package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.os.Bundle
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

class MainActivity : FlutterActivity() {
    private var homeworkFileSaver: HomeworkFileSaver? = null
    private var settingsHandler: SystemSettingsHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        homeworkFileSaver = HomeworkFileSaver(this).also {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.edu.buaa.ginkgo/homework-files").setMethodCallHandler(it)
        }
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "cn.edu.buaa.ginkgo/learning-snapshots",
            StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
            .setMethodCallHandler(LearningSnapshotHandler(applicationContext))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.edu.buaa.ginkgo/update")
            .setMethodCallHandler(UpdateInstaller(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.edu.buaa.ginkgo/reminders")
            .setMethodCallHandler(ReminderScheduler(applicationContext))
        settingsHandler = SystemSettingsHandler(this).also {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.edu.buaa.ginkgo/system")
                .setMethodCallHandler(it)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (homeworkFileSaver?.onResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        homeworkFileSaver?.dispose()
        homeworkFileSaver = null
        super.onDestroy()
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
