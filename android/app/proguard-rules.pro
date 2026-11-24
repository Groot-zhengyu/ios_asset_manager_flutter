# ---------------------------------------------------------------------------
# Google ML Kit（中文文字识别）
#
# 1) google_mlkit_text_recognition 插件在 TextRecognizer.initialize 里按语言
#    分支引用 mlkit 各语种识别器的 Options 类（devanagari / japanese / korean
#    等），而本项目只打包了中文模型（text-recognition-chinese），其余语种类
#    不存在，R8 需忽略这些缺失引用。
# 2) ML Kit 内部大量使用反射与 Class.forName 做模型注册，R8 混淆后会拿到
#    null 并抛 NullPointerException: Attempt to invoke virtual method
#    'java.lang.Class java.lang.Object.getClass()' on a null object reference。
#    因此必须整体保留 ML Kit 及其内部实现类。
# ---------------------------------------------------------------------------
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.internal.vision.** { *; }

# 插件侧通过 MethodChannel 调用的入口
-keep class io.flutter.plugin.common.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
