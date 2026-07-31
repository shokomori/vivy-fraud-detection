-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# ML Kit text recognition — only the default (Latin) script is bundled.
# These classes are intentionally absent since we don't use the other scripts.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**

# General ML Kit safety net
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }