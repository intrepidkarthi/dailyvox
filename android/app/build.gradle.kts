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
        minSdk = 26
        // 36 is mandatory for new apps from 2026-08-31. Set from the first
        // commit rather than retrofitted: it forces edge-to-edge and predictive
        // back, and both are far cheaper to build in than to add later.
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    debugImplementation(libs.compose.ui.tooling)
}
