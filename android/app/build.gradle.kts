import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in `android/key.properties`, which is
// git-ignored along with the keystore it points at (see android/.gitignore).
// The file is read here rather than injected as `-P` flags so the values never
// appear in a process listing or in CI logs.
//
// The Flutter template's fallback — signing `release` with the debug key — was
// removed in Phase 10. It produced a build that installs everywhere and is
// accepted by no store, which is the worst of both outcomes: the failure is
// discovered at upload time rather than at build time. A release build now
// stops here instead (**D-62**).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        // `Properties.load` reads ISO-8859-1 and treats a UTF-8 byte-order mark
        // as part of the first key's name, so a `key.properties` saved by
        // Notepad or by PowerShell's `Set-Content -Encoding UTF8` would
        // silently yield no `storeFile` and fail with the "no release signing
        // key" message even though the file is right there. That is a
        // confusing enough failure — on a file a developer hand-writes and
        // never expects to be encoding-sensitive — to be worth absorbing here.
        val bytes = keystorePropertiesFile.readBytes()
        val body = if (bytes.size >= 3 &&
            bytes[0] == 0xEF.toByte() &&
            bytes[1] == 0xBB.toByte() &&
            bytes[2] == 0xBF.toByte()
        ) {
            bytes.copyOfRange(3, bytes.size)
        } else {
            bytes
        }
        body.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

// A release build with no keystore is a configuration error, not something to
// paper over. Checked here, before `android { }`, because assigning
// `buildTypes.release.signingConfig` to a name that was never created fails
// first with Gradle's own "SigningConfig with name 'release' not found" — a
// message that names neither the missing file nor the fix.
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
if (isReleaseBuild && !hasReleaseKeystore) {
    throw GradleException(
        """
        |
        |No release signing key found.
        |
        |Create `android/key.properties` next to this file:
        |
        |    storeFile=<path to your upload keystore, relative to android/>
        |    storePassword=<keystore password>
        |    keyAlias=<key alias>
        |    keyPassword=<key password>
        |
        |Generate a keystore with (JDK 17's keytool is on PATH):
        |
        |    keytool -genkeypair -v -keystore android/calculator-upload.jks \
        |      -keyalg RSA -keysize 2048 -validity 10000 -alias upload
        |
        |`key.properties` and `*.jks` are git-ignored. Back the keystore up
        |somewhere outside this repository: losing it means you can never
        |update the published app.
        |
        |To build locally against the debug key instead, run the debug
        |variant: `flutter build apk --debug`.
        |
        """.trimMargin(),
    )
}

android {
    namespace = "com.hasanmahadi.calculator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Fixed by **D-12** and mirrored by `AppInfo.androidPackageName`
        // (`lib/core/config/app_info.dart`), which composes the Play Store URL
        // from it. Changing one without the other breaks the Rate App fallback
        // and the Share App message.
        applicationId = "com.hasanmahadi.calculator"
        // minSdk 24, targetSdk 36 as shipped by the Flutter SDK defaults.
        // targetSdk 36 satisfies Google Play's 31 Aug 2026 requirement for new
        // apps; both are asserted against the built APK in Phase 10.
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
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // `findByName` rather than `getByName`: this line is evaluated at
            // configuration time for *every* variant, so `getByName("release")`
            // throws "SigningConfig with name 'release' not found" even for a
            // debug build whenever no keystore is configured — which would make
            // the signing requirement block local development entirely.
            //
            // Reaching the null branch at all is already impossible for a real
            // release build: the check above throws first. This only keeps
            // `flutter build apk --debug` and `flutter run` working on a machine
            // with no upload key, which is the normal state of a fresh clone.
            signingConfig = signingConfigs.findByName("release")
            // R8 code shrinking and resource shrinking for the shipped build
            // (**D-64**), both off by default in the Flutter template.
            //
            // Measured caveat: this saves almost nothing here. The release APK is
            // 48.4 MB, of which 47.3 MB is native code — `libflutter.so` and
            // `libapp.so` for three ABIs — and only 0.95 MB is dex. R8 shrinks
            // the dex, so the total barely moves. The size lever is the App
            // Bundle (Play serves one ABI per device) or `--split-per-abi`, not
            // R8; see **D-63**.
            //
            // R8 is kept on anyway because it is the correct release posture
            // (it strips the unused Java/Kotlin surface and Android resources)
            // and costs nothing. `proguard-rules.pro` is deliberately
            // near-empty: the Flutter Gradle plugin contributes the engine's own
            // keep rules, and both plugins in use (`in_app_review`, `share_plus`)
            // are reached over platform channels rather than reflection. If a
            // future plugin needs a keep rule, that file is where it goes.
            isMinifyEnabled = true
            isShrinkResources = true
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
