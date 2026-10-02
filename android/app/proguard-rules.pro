# R8 rules for release builds (minify + shrink are on in app/build.gradle.kts).
# Flutter and most plugins ship their own consumer rules; these cover code that
# is reached by reflection or from native/manifest entries.

# This app's Kotlin code: call detection service, plugin and receivers.
-keep class com.smartbroker.smart_broker.** { *; }

# flutter_overlay_window: its OverlayService is started from Dart by class name.
-keep class flutter.overlay.window.** { *; }

# flutter_local_notifications serialises scheduled notifications with Gson.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Optional Play Core classes referenced by the Flutter engine (deferred components).
-dontwarn com.google.android.play.core.**
