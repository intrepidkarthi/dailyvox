import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.compose.compiler)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.dailyvox.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.dailyvox.app"
        // 33, not 26. Below API 33 there is no on-device speech recognizer, and
        // SpeechCapture will not use any other kind -- so on Android 12 and
        // older this app installs and can never record a single entry. Play
        // filtering by minSdk is how a phone that cannot run it never sees it,
        // which is better than an install that fails at the first tap.
        minSdk = 33
        // 36 is mandatory for new apps from 2026-08-31. Set from the first
        // commit rather than retrofitted: it forces edge-to-edge and predictive
        // back, and both are far cheaper to build in than to add later.
        targetSdk = 36
        // Android's own line, starting at 1.0. It is deliberately not 1.11.0:
        // matching the iOS number would claim a parity this port does not have
        // (no cloud sync, no live Dynamic-Island transcription, no Body cards).
        versionCode = 1
        versionName = "1.0"
    }

    // Signing credentials live in keystore.properties, which is gitignored and
    // never committed. Absent, the release build still runs and produces an
    // UNSIGNED bundle -- CI and anyone without the key can keep building, and
    // the only thing they cannot do is upload.
    val keystoreProperties = Properties().apply {
        val f = rootProject.file("keystore.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
    kotlin { jvmToolchain(21) }
    buildFeatures { compose = true }
    ksp { arg("room.schemaLocation", "$projectDir/schemas") }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.material3)
    implementation(libs.activity.compose)
    implementation(libs.navigation.compose)
    implementation(libs.adaptive.navigation.suite)
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.datastore.preferences)
    implementation(libs.biometric)
    implementation("androidx.fragment:fragment-ktx:1.8.5")
    implementation(libs.security.crypto)
    implementation(libs.health.connect)
    implementation(project(":engine"))
    testImplementation(libs.junit)
    debugImplementation(libs.compose.ui.tooling)
}
