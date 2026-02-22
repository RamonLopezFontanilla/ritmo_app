plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // FlutterFire
}

import java.util.Properties
import java.io.FileInputStream

// ------------------ CONFIGURACIÓN DE KEYS ------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
     namespace = "com.ramonlf.ritmoapp"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.ramonlf.ritmoapp"
        minSdk = flutter.minSdkVersion
        targetSdk = 36

        // ---------------- Auto-increment versionCode ----------------
        val baseVersionCode = 1
        val lastVersionCodeFile = rootProject.file("version.properties")
        val lastVersionCode = if (lastVersionCodeFile.exists()) {
            Properties().apply { load(lastVersionCodeFile.inputStream()) }
                .getProperty("VERSION_CODE")?.toInt() ?: baseVersionCode
        } else baseVersionCode

        val newVersionCode = lastVersionCode + 1

        versionCode = newVersionCode
        versionName = "1.0.$newVersionCode"

        // Guardar el nuevo versionCode en version.properties
        lastVersionCodeFile.outputStream().use {
            Properties().apply {
                setProperty("VERSION_CODE", newVersionCode.toString())
            }.store(it, null)
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}
