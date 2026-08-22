import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("keystore.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

val signingFields =
    mapOf(
        "storeFile" to "DANGGUI_KEYSTORE_PATH",
        "storePassword" to "DANGGUI_KEYSTORE_PASSWORD",
        "keyAlias" to "DANGGUI_KEY_ALIAS",
        "keyPassword" to "DANGGUI_KEY_PASSWORD",
    )
val environmentSigningValues =
    signingFields.mapValues { (_, environmentName) ->
        providers.environmentVariable(environmentName).orNull?.trim()?.takeIf(String::isNotEmpty)
    }
val propertySigningValues =
    signingFields.mapValues { (propertyName, _) ->
        signingProperties.getProperty(propertyName)?.trim()?.takeIf(String::isNotEmpty)
    }
val configuredEnvironmentValueCount = environmentSigningValues.values.count { it != null }
val configuredPropertyValueCount = propertySigningValues.values.count { it != null }

if (configuredEnvironmentValueCount in 1..3) {
    throw GradleException(
        "Release signing environment variables are only partially configured. " +
            "Provide all four DANGGUI_KEYSTORE_* variables or clear all four.",
    )
}
if (configuredEnvironmentValueCount == 0 && signingPropertiesFile.exists() && configuredPropertyValueCount != 4) {
    throw GradleException(
        "android/keystore.properties is only partially configured. " +
            "Provide storeFile, storePassword, keyAlias and keyPassword, or remove the file.",
    )
}

val releaseSigningValues =
    if (configuredEnvironmentValueCount == 4) environmentSigningValues else propertySigningValues
val hasReleaseSigning = releaseSigningValues.values.all { it != null }
val releaseKeystoreFile = releaseSigningValues["storeFile"]?.let(rootProject::file)
if (hasReleaseSigning && releaseKeystoreFile?.isFile != true) {
    throw GradleException("Configured release keystore does not exist: $releaseKeystoreFile")
}

android {
    namespace = "com.danggui.memo"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.danggui.memo"
        minSdk = 24
        targetSdk = 36
        multiDexEnabled = true
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = releaseKeystoreFile
                storePassword = releaseSigningValues.getValue("storePassword")
                keyAlias = releaseSigningValues.getValue("keyAlias")
                keyPassword = releaseSigningValues.getValue("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    logger.warn(
                        "DANGGUI RELEASE SIGNING: no release credentials were provided; " +
                            "the release artifact will be signed with the debug key and must not be published.",
                    )
                    signingConfigs.getByName("debug")
                }
            isDebuggable = false
        }
    }

    lint {
        abortOnError = true
        checkReleaseBuilds = true
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
