import java.io.FileInputStream
import java.util.Properties

// Release signing material. key.properties and the keystore itself are both
// gitignored (see android/.gitignore) so the password never reaches the repo;
// keep the .jks outside the project directory and backed up somewhere durable.
// Losing it means no future build can update an already-installed copy of the
// app, because Android refuses a signature change on upgrade.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasKeystore) FileInputStream(keystorePropertiesFile).use { load(it) }
}
if (!hasKeystore) {
    logger.warn(
        "\n*** android/key.properties not found - release builds will be signed " +
        "with DEBUG keys. An APK signed this way cannot be updated later from a " +
        "machine with a different debug keystore. See deployment notes. ***\n"
    )
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jinwei.scandy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jinwei.scandy"
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
        // Only declared when the properties file is present, so a checkout
        // without the keystore still configures instead of failing outright.
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // The real key when it is available, debug otherwise so that
            // `flutter run --release` still works on a fresh clone. The warning
            // above is what stops that fallback from being silent.
            signingConfig = signingConfigs.getByName(if (hasKeystore) "release" else "debug")
            // proguard-rules.pro explains why: ML Kit's other script models are
            // referenced by the plugin but deliberately not bundled.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
