# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Hiddify Core (native library bindings)
-keep class com.hiddify.core.** { *; }
-keep class go.** { *; }
-keep class libbox.** { *; }

# Wire protobuf generated classes
-keep class com.hiddify.core.api.** { *; }
-keep class com.squareup.wire.** { *; }
-dontwarn com.squareup.wire.**

# gRPC
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**

# Keep AIDL interfaces
-keep class xyz.psroute.app.IService { *; }
-keep class xyz.psroute.app.IServiceCallback { *; }

# Keep app classes used via reflection
-keep class xyz.psroute.app.** { *; }

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.** { *; }

# AndroidX
-dontwarn androidx.**
