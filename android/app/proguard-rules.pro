# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Models & Services (Important pour JSON et Database)
-keep class com.example.loyambo.kernel.models.** { *; }
-keep class com.example.loyambo.kernel.services.** { *; }

# Correction pour les erreurs Play Core en mode Release
-dontwarn com.google.android.play.core.**
