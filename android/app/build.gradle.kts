plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dpterm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    lint {
        disable +="ExpiredTargetSdkVersion"
    }
    splits { // 配置 ABI 分拆
        abi {
            isEnable = true // 注意：Kotlin 中使用 isEnable
            reset()         // 清除默认的所有架构
            isUniversalApk = false // 是否生成一个包含所有架构的胖 APK
        }
    }
    
    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dpterm"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        // IMPORTANT: targetSdk must be 28 or lower to allow executing binaries
        // from /data/data directory. Android 10+ (API 29+) enforces SELinux
        // policies that block execution from app_data_file contexts.
        // See: https://github.com/termux/termux-app/issues/1072
        targetSdk = 28
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
