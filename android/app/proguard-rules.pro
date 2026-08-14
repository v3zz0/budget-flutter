# google_mlkit_text_recognition referenzia i riconoscitori di tutte le lingue,
# ma nell'APK spediamo solo quello latino. R8 non trova gli altri e si ferma:
# qui gli diciamo che è normale. Regole generate da R8 stesso in
# build/app/outputs/mapping/release/missing_rules.txt
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
