import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리즈 서명 키 — `android/key.properties`에서 읽는다.
//
// ⚠️ 이 파일과 키스토어는 **레포에 들어가지 않는다**(`android/.gitignore`).
// 각자 로컬에 두고, 키스토어 원본은 레포 밖에 따로 백업해야 한다 — 이 키를
// 잃어버리면 그 시점 이후로 업데이트를 영영 못 낸다(서명이 다르면 기존
// 설치본 위에 덮어쓰기가 거부된다).
//
// 2026-09-21까지는 Flutter 템플릿 기본값대로 **디버그 키로 릴리즈를
// 서명**하고 있었다. 그 상태로 배포한 APK(0.122.0+306까지)는 릴리즈 키
// 빌드로 업데이트되지 않으니 받은 사람이 지우고 다시 깔아야 한다.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) keystorePropertiesFile.inputStream().use { load(it) }
}

// key.properties 없이 릴리즈를 만들면 **조용히 디버그 키로 서명되는 게 가장
// 위험하다** — 배포하고 나서야 알게 되고, 그때는 되돌리는 비용을 받는 사람이
// 치른다. 그래서 디버그 키로 떨어지는 대신 릴리즈 빌드만 골라서 세운다.
// (디버그 빌드·테스트는 키스토어 없이도 그대로 돌아간다.)
gradle.taskGraph.whenReady {
    if (!hasReleaseKeystore && allTasks.any { it.name.contains("Release") }) {
        throw GradleException(
            "릴리즈 서명 키가 없습니다: ${keystorePropertiesFile.absolutePath}\n" +
                "키스토어를 만든 뒤 key.properties에 storeFile/storePassword/" +
                "keyAlias/keyPassword 네 줄을 채우세요.\n" +
                "  keytool -genkey -v -keystore ~/vivanaut-release.jks " +
                "-keyalg RSA -keysize 2048 -validity 10000 -alias vivanaut"
        )
    }
}

android {
    namespace = "com.vivanaut.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications가 java.time 등 신규 API를 쓴다 — 구형
        // Android에서 돌리려면 desugaring 필수 (플러그인 요구사항).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.vivanaut.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
