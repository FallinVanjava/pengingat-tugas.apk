# Aturan ProGuard untuk flutter_local_notifications + Gson
# Mencegah crash "Missing type parameter" pada loadScheduledNotifications
# (R8 memangkas generic signature TypeToken yang dibaca Gson via reflection)

-keep class com.dexterous.flutterlocalnotifications.** { *; }

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class com.google.gson.internal.bind.TypeAdapters { *; }
-keep,allowobfuscation @interface com.google.gson.annotations.SerializedName
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Hive
-keep class io.flutter.plugins.** { *; }
-keep class com.ryanheise.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.gson.**
