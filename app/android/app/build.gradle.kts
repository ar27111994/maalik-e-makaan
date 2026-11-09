import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Values come from MM_ANDROID_* environment variables (CI) or,
// failing those, from app/android/key.properties (a developer machine; never
// committed). Without a keystore, release builds use the debug key so that
// `flutter run --release` works locally; the release workflow sets
// MM_REQUIRE_RELEASE_SIGNING=true so a missing keystore fails the build instead
// of shipping a debug-signed app.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}

fun signingValue(property: String, variable: String): String? =
    System.getenv(variable)?.takeIf { it.isNotBlank() }
        ?: keystoreProperties.getProperty(property)?.takeIf { it.isNotBlank() }

val releaseStorePath = signingValue("storeFile", "MM_ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "MM_ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "MM_ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "MM_ANDROID_KEY_PASSWORD")
val hasReleaseKeystore = releaseStorePath != null

if (hasReleaseKeystore &&
    listOf(releaseStorePassword, releaseKeyAlias, releaseKeyPassword).any { it == null }
) {
    throw GradleException(
        "A release keystore is configured but its store password, key alias or key " +
            "password is missing (MM_ANDROID_* variables or key.properties).",
    )
}
if (System.getenv("MM_REQUIRE_RELEASE_SIGNING") == "true" && !hasReleaseKeystore) {
    throw GradleException(
        "MM_REQUIRE_RELEASE_SIGNING is set but no release keystore is configured " +
            "(MM_ANDROID_KEYSTORE_PATH or storeFile in key.properties).",
    )
}

android {
    namespace = "io.github.ar27111994.maalik_e_makaan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.ar27111994.maalik_e_makaan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKeystore) "release" else "debug")
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
