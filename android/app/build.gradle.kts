import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties, which is
// gitignored. The keystore itself is stored OUTSIDE the repository.
//
// If the file is absent (a fresh clone, or CI without secrets), release builds
// fall back to debug signing so the project still builds — but such an APK
// cannot be published and cannot update an existing install.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseSigning = keystorePropertiesFile.exists() &&
        keystoreProperties.getProperty("storeFile") != null

// If key.properties exists it must be usable — silently falling back to debug
// signing here would produce an unpublishable APK that looks successful.
// Note: storeFile must be an absolute path in Windows form (C:/...), not a
// Git Bash path (/c/...), which Gradle resolves relative to the module.
if (hasReleaseSigning) {
    val ks = file(keystoreProperties.getProperty("storeFile"))
    require(ks.exists()) {
        "android/key.properties points at a keystore that does not exist:\n" +
        "  configured: ${keystoreProperties.getProperty("storeFile")}\n" +
        "  resolved:   ${ks.absolutePath}\n" +
        "Use an absolute path such as C:/Users/<you>/bsg-release-key.jks"
    }
}

android {
    // Reverse-DNS of bestsmartgame.com. namespace, applicationId and the Kotlin
    // source package are all deliberately identical — they were three different
    // values (com.bsg.best_smart_game / com.bsg.game / com.bsg.best_smart_game)
    // before v2.0.0.
    namespace = "com.bestsmartgame.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // WARNING: this is the app's permanent identity on Google Play. It can
        // never be changed once published — a different value is a different
        // app, with a new listing and no update path from this one.
        applicationId = "com.bestsmartgame.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Debug fallback so the project still builds without secrets.
                logger.warn("⚠  android/key.properties not found — signing the RELEASE build with the DEBUG key. This APK cannot be published or used to update an existing install.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
