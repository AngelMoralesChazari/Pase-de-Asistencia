plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.pase_de_asistencia"
    compileSdk = flutter.compileSdkVersion.toInt()
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Solución 1: Usa mutableMapOf directamente
        manifestPlaceholders += mutableMapOf(
            "appAuthRedirectScheme" to "com.googleusercontent.apps.200627463961"
        )

        // Solución alternativa 2 (si la anterior falla):
        // manifestPlaceholders = mapOf(
        //     "appAuthRedirectScheme" to "com.googleusercontent.apps.200627463961"
        // ).toMutableMap()

        applicationId = "com.example.pase_de_asistencia"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion.toInt()
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.2.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
}

flutter {
    source = "../.."
}