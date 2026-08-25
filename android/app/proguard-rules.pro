# R8 rules for the release build.
#
# This file is named by app/build.gradle.kts and did not exist, so every release
# build printed "Supplied proguard configuration does not exist" and carried on
# with only the default optimize config. It built and it shrank; the problem is
# that any rule anyone thought they had added was silently absent, and a missing
# keep rule does not fail the build — it fails on a user's phone, in a code path
# nobody exercised before shipping.
#
# The app needs very little, and that is worth stating so nobody adds rules
# defensively:
#
#   * Room, Compose, DataStore, Health Connect and androidx.biometric all ship
#     their own consumer rules inside their AARs. Repeating them here would only
#     create a second copy to fall out of date.
#   * Manifest-declared components — MainActivity, the two widget providers, the
#     Quick Settings tile, both receivers, FileProvider — are kept automatically
#     by AGP, which reads the merged manifest.
#   * Nothing in this app reflects over its own types. Exports build JSON with
#     buildString rather than Gson or Moshi, so there are no field names for R8
#     to rename out from under a serializer. If that ever changes, the rule
#     belongs here and so does the reason.

# The engine's boundary types cross a module edge and are constructed by name
# nowhere, so R8 may rename them freely. Kept anyway: they are the wire format
# between the app and the Twin, and `.twin` export files written by one build
# have to be readable by the next. Renaming is invisible until a user restores a
# backup taken before an update.
-keep class com.dailyvox.twin.ChatEntry { *; }

# Line numbers in a crash report, without shipping the rest of the debug
# metadata. There is no crash reporter — this is for a stack trace someone
# pastes into an issue, which is the only telemetry this app will ever have.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
