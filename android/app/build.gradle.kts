plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mutfak_asistani"
    compileSdk = 36 // Zorla 34 (En kararlı sürüm)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.mutfak_asistani"
        minSdk = flutter.minSdkVersion
        targetSdk = 36 // Zorla 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true 
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    // Bu satır bazen 'resource not found' hatalarını çözer, çünkü eksik kaynakları tamamlar:
    implementation("androidx.appcompat:appcompat:1.6.1") 
}
