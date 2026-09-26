import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(keyPropertiesFile.inputStream())
}

val pubspecFile = rootProject.file("../pubspec.yaml")
val pubspecVersion = pubspecFile.readLines()
    .firstOrNull { it.startsWith("version:") }
    ?.removePrefix("version:")
    ?.trim() ?: "1.0.0+1"
val pubspecVersionName = pubspecVersion.substringBefore("+")
val pubspecVersionCode = pubspecVersion.substringAfter("+", "1").toIntOrNull() ?: 1

android {
    namespace = "com.yamaguchi.shiori"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "com.yamaguchi.shiori2"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = pubspecVersionCode
        versionName = pubspecVersionName
    }

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = false
        isShrinkResources = false
    }
  }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.android.gms:play-services-auth:21.2.0")
}
