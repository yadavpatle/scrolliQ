# Keep Flutter Embedding & Play Core (used by deferred components / FCM)
-keep class io.flutter.embedding.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.posthog.** { *; }

# Keep model classes used reflectively (none right now, but reserved for json-serializable)
-keepattributes *Annotation*

# OkHttp / Conscrypt warnings
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn org.bouncycastle.**

# Flutter references Play Core deferred-component classes via reflection in
# PlayStoreDeferredComponentManager, but ScrollIQ doesn't ship deferred
# components, so the dependency isn't on the classpath. Tell R8 to ignore.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Flutter references Play Core deferred-component classes via reflection in
# PlayStoreDeferredComponentManager, but ScrollIQ doesn't ship deferred
# components, so the dependency isn't on the classpath. Tell R8 to ignore.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
