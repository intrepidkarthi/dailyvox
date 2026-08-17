pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
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
