plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase plugin
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.info_sphere"
    compileSdk = 35 // Use SDK 35 for compatibility with newer plugins

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // Use Java 8 for Flutter compatibility
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true // Enable core library desugaring
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString() // Use Java 8 for Kotlin
    }

    defaultConfig {
        applicationId = "com.example.info_sphere"
        minSdk = 23 // Set this to 23 for Firebase Auth compatibility
        targetSdk = 35 // Use SDK 35 for compatibility with newer plugins
        versionCode = 1 // Set your version code
        versionName = "1.0" // Set your version name
        multiDexEnabled = true // Enable multiDex for larger apps
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // Use debug keys for testing
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Add the core library desugaring dependency
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") // Use 2.1.4 or higher
    implementation("androidx.multidex:multidex:2.0.1") // Add multiDex dependency
}