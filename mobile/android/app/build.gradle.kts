plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// API ключ для Google Maps: local.properties > google-services.json
val localPropertiesFile = rootProject.file("local.properties")
val mapsApiKeyFromLocal = localPropertiesFile.takeIf { it.exists() }?.let { file ->
    """GOOGLE_MAPS_API_KEY=(.+)""".toRegex().find(file.readText())?.groupValues?.get(1)?.trim()
}
val mapsApiKey = mapsApiKeyFromLocal
    ?: run {
        val googleServicesFile = file("google-services.json")
        if (googleServicesFile.exists()) {
            """"current_key"\s*:\s*"([^"]+)"""".toRegex()
                .find(googleServicesFile.readText())?.groupValues?.get(1) ?: "YOUR_API_KEY"
        } else {
            "YOUR_API_KEY"
        }
    }

android {
    namespace = "com.kitakitar.app"
    compileSdk = 36  // Требуется плагинами (camera, google_maps, etc.)
    // ndkVersion = flutter.ndkVersion  // Отключено, чтобы избежать проблем с установкой NDK

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kitakitar.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 34  // Можно оставить 34, compileSdk может быть выше
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsApiKey
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
