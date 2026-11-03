plugins {
  kotlin("multiplatform") version "2.3.20"
  kotlin("plugin.serialization") version "2.3.20"
}

val ubaaRoot = file(providers.gradleProperty("ubaaRoot").get())
layout.buildDirectory.set(file(providers.gradleProperty("oracleBuildDir").get()))

kotlin {
  jvm()
  jvmToolchain(21)
  compilerOptions { freeCompilerArgs.add("-Xexpect-actual-classes") }

  sourceSets {
    commonMain {
      kotlin.srcDir(ubaaRoot.resolve("shared/src/commonMain/kotlin"))
      dependencies {
        implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.10.0")
        implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.7.1")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
        implementation("io.ktor:ktor-client-core:3.4.1")
        implementation("io.ktor:ktor-client-content-negotiation:3.4.1")
        implementation("io.ktor:ktor-serialization-kotlinx-json:3.4.1")
        implementation("io.ktor:ktor-client-logging:3.4.1")
        implementation("io.ktor:ktor-client-auth:3.4.1")
        implementation("com.russhwolf:multiplatform-settings:1.3.0")
        implementation("com.russhwolf:multiplatform-settings-no-arg:1.3.0")
      }
    }
    jvmMain {
      kotlin.srcDir(ubaaRoot.resolve("shared/src/jvmMain/kotlin"))
      dependencies {
        implementation("io.ktor:ktor-client-cio:3.4.1")
        implementation("io.ktor:ktor-client-okhttp:3.4.1")
      }
    }
    commonTest {
      kotlin.srcDir(ubaaRoot.resolve("shared/src/commonTest/kotlin"))
      dependencies {
        implementation(kotlin("test"))
        implementation("io.ktor:ktor-client-mock:3.4.1")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
        implementation("com.russhwolf:multiplatform-settings-test:1.3.0")
      }
    }
  }
}

tasks.register("resolveOracleDependencies") {
  doLast {
    configurations.filter { it.isCanBeResolved }.forEach { it.resolve() }
  }
}

tasks.withType<Test>().configureEach {
  systemProperty("java.util.prefs.userRoot", layout.buildDirectory.dir("synthetic-prefs").get().asFile.absolutePath)
}
