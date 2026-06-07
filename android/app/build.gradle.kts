plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.nowfishing.app"
    compileSdk = 36       // ✅ 1-1: API 35로 고정
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.nowfishing.app"
        minSdk = 26
        targetSdk = 36      // ✅ 1-1: API 35 타겟
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("nowfishing.jks")
            storePassword = "59suxr12@"
            keyAlias = "nowfishing"
            keyPassword = "59suxr12@"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // ✅ 1-4: ProGuard/R8 난독화 + 리소스 축소
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}