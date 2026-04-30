plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.chwcopilot.chw_copilot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.chwcopilot.chw_copilot"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26  // Android 8.0 required for LiteRT-LM GPU delegate
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // =========================================================
    // DAY 1 SPIKE: Uncomment ONE of these.
    //
    // OPTION A — LiteRT-LM (primary):
    // implementation("com.google.ai.edge.litert:litert-lm:1.0.0-beta1")
    //
    // OPTION B — MediaPipe fallback (if Option A fails):
    // implementation("com.google.mediapipe:tasks-genai:0.10.22")
    //
    // Then uncomment the matching block in LiteRtBridge.kt.
    // =========================================================
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
