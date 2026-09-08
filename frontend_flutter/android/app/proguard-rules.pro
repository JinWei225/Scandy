# --- ML Kit text recognition -------------------------------------------------
#
# Two separate problems, both only visible in a release build.
#
# 1. The Flutter plugin references a recognizer class per script from its
#    initialize() switch. Scandy depends on the Latin model alone — the others
#    would add tens of megabytes for languages these receipts do not use — so R8
#    sees the references and fails the build with
#    "Missing class com.google.mlkit.vision.text.chinese...".
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# 2. ML Kit resolves parts of itself by class, so minifying its internals makes
#    processImage() throw NullPointerException at runtime — a build that ships
#    fine and then fails on the first scan, which is the worst shape of bug.
#    Keeping these is what makes the release build actually scan.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
