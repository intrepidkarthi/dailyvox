pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}

// Lets Gradle fetch the JDK a module's toolchain asks for instead of failing.
// The engine pins jvmToolchain(21) and forces the compile into that JDK, but a
// toolchain is only a REQUEST -- with no resolver and no JDK 21 installed,
// Gradle falls back to whatever is running. On a machine with only JDK 26 that
// means the Kotlin compiler parses "26.0.2", does not recognise it, and dies
// with IllegalArgumentException. The app module never showed it because AGP
// forks its own. This is also what the engine's CI runner was missing.
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "DailyVox"
include(":app")

// The Twin engine is PROPRIETARY and lives in the private repo
// (github.com/intrepidkarthi/DailyVoxTwin), checked out alongside this one. It
// is the Kotlin peer of the Swift package the iOS app consumes over SPM, and it
// is absent from this repository by design.
//
// Fail LOUDLY rather than degrading. A build that silently produced an app with
// no name detection and every mood at 0.00 would look like a working app right
// up until someone trusted it.
val enginePath = File(rootDir, "../DailyVoxTwin/kotlin/engine")
if (enginePath.exists()) {
    include(":engine")
    project(":engine").projectDir = enginePath
} else {
    throw GradleException(
        """
        The DailyVox Twin engine was not found at ${'$'}{enginePath.canonicalPath}.

        This repository is the app only. The Twin engine is a separate private
        package and must be checked out next to it:

            git clone git@github.com:intrepidkarthi/DailyVoxTwin.git

        so the two sit side by side:

            voicetotext/
              android/          <- you are here
              DailyVoxTwin/     <- the engine

        Contributors without engine access can still build and run everything
        else; see android/README.md for the stub instructions.
        """.trimIndent()
    )
}
