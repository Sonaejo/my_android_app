plugins {
    id("com.android.application")
    kotlin("android") // ← id("kotlin-android") ではなくこちらを推奨
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pushup_counter"

    // Flutter のバージョン管理値を使用
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        // ← 必ず自分のIDに変更してください（後ででもOK）
        applicationId = "com.example.pushup_counter"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        // デバッグは縮小系をOFF（今回のビルドエラー対策の肝）
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        // リリースは必要に応じてON
        getByName("release") {
            // とりあえずデバッグ鍵で署名（flutter run --release 用）
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Java/Kotlin 17（Flutter 3.35 の推奨）
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // ★ ここを true に変更（desugaring 有効化）
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // まれにライセンス衝突を避けるための除外
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// Flutter モジュールの場所
flutter {
    source = "../.."
}

dependencies {
    // --- ML Kit Pose（オンデバイス推論） ---
    implementation("com.google.mlkit:pose-detection-accurate:17.0.0")

    // --- CameraX（ビデオ入力） ---
    val cameraVersion = "1.3.4"
    implementation("androidx.camera:camera-core:$cameraVersion")
    implementation("androidx.camera:camera-camera2:$cameraVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraVersion")
    implementation("androidx.camera:camera-view:$cameraVersion")

    // ★ これを有効化（Java 8+ API desugaring）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
