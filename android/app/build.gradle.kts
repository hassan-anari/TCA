import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Prototype signing: CI generates a throwaway keystore and writes
// android/key.properties (never committed). Without it, local release builds
// fall back to the Android debug key so `flutter run --release` still works.
val keyProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasPrototypeKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "app.memoria.prototype"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Temporary prototype application ID (not a production identifier).
        applicationId = "app.memoria.prototype.phase00"
        // Android 10 (API 29). Thermion/Filament itself only needs API 22.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // `--target-platform` only filters Flutter's own engine/AOT libraries;
        // plugin JNI libraries (jni, datastore, thermion_flutter) would still
        // ship for every ABI. Restrict packaged native libs to the requested
        // ABIs so the arm64 deliverable is arm64-only (and the emulator's
        // x86_64 build stays x86_64-only).
        val requestedAbis =
            (project.findProperty("target-platform") as String?)
                ?.split(",")
                ?.mapNotNull {
                    when (it.trim()) {
                        "android-arm64" -> "arm64-v8a"
                        "android-x64" -> "x86_64"
                        "android-arm" -> "armeabi-v7a"
                        else -> null
                    }
                }
                .orEmpty()
        if (requestedAbis.isNotEmpty()) {
            ndk { abiFilters += requestedAbis }
        }
    }

    signingConfigs {
        create("prototype") {
            if (hasPrototypeKey) {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasPrototypeKey) signingConfigs.getByName("prototype")
                else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
