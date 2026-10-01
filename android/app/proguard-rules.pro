# R8 rules for the release build (**D-64**).
#
# Intentionally almost empty. The Flutter Gradle plugin contributes the keep
# rules the Dart engine and the embedding need, and this app's two plugins
# (`in_app_review`, `share_plus`) are reached over platform channels rather
# than reflection, so neither is stripped.
#
# The failure mode of a missing rule is a crash at runtime that no build-time
# check can catch, so anything added here needs a device to verify — which is
# the reason this file is a short list rather than a growing one.

# Keep line numbers for readable Play Console crash reports, but still hide the
# original source file name.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
