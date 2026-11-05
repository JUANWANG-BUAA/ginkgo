package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.content.Context

internal object GinkgoNativeRuntime {
    private var initialized = false
    @Synchronized fun initialize(context: Context) {
        if (initialized) return
        System.loadLibrary("ginkgo_flutter_bridge")
        CredentialVault.initialize(context.applicationContext)
        initialized = true
    }
}
