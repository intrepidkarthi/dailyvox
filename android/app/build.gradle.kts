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
        // MUST increase on every single upload, and a number can never be
        // reused — not even for a build Play rejected. Play refuses a release
        // whose bundle offers nothing newer than what a tester already has, and
        // it says so in two errors at once that do not obviously mean this:
        //
        //   "This release does not add or remove any app bundles."
        //   "You can't rollout this release because it doesn't allow any
        //    existing users to upgrade to the newly added app bundles."
        //
        // Both mean the same thing: there is no bundle here that anybody could
        // upgrade TO. Bump this, rebuild, re-upload. To move an ALREADY
        // uploaded build between tracks, do not create a release at all — use
        // Promote release on the track that has it.
        // 3 because 2 is already uploaded. This has now cost two rejected
        // releases, so the rule is worth stating flatly: the number has to beat
        // what is IN THE STORE, not what was last built here. A local bump is
        // not evidence the number is free — check the Play Console release
        // list, or `./gradlew :app:bundleRelease` will happily produce a
        // duplicate Play refuses on upload.
        versionCode = 4
        versionName = "1.0"

        // Demo journal entries, for store screenshots ONLY.
        //
        // These are fabricated diary entries about people who do not exist --
        // Sarah, James, Emma, Priya -- and Repo.seedIfEmpty wrote all 38 of
        // them into the database on first launch, unconditionally, in every
        // build. A person who installed the app opened their private journal
        // and found somebody else's life already in it, with no way to tell
        // which entries were theirs. It read as a bug in the worst possible
        // place: the one screen whose entire promise is that it holds only what
        // you said.
        //
        // The flag is off by default and forced off in release below, so
        // producing screenshots now takes a deliberate:
        //
        //     ./gradlew installDebug -PseedDemo
        //
        // and nothing else, ever, gets the data.
        buildConfigField(
            "boolean",
            "SEED_DEMO_DATA",
            (project.hasProperty("seedDemo")).toString(),
        )
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
            // Belt and braces with the DEBUG guard at the call site: -PseedDemo
            // on a release build must not be a way to ship the demo journal.
            buildConfigField("boolean", "SEED_DEMO_DATA", "false")
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
    buildFeatures { compose = true; buildConfig = true }
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
    // Robolectric only for tests that need a real SQLite: the Room migrations,
    // which must survive running against a table that is already ahead.
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("androidx.test:core:1.6.1")
    debugImplementation(libs.compose.ui.tooling)
}
