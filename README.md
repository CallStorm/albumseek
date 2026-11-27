# albumseek

On-device photo search for a person's camera roll. OCR, embeddings, and short labels run on the phone after you download the model files. The library grid still opens when those files are missing.

## What this version does

- Asks for permission to read images stored on the phone, and explains what to do when that permission is denied.
- Shows a scrollable grid of those images while indexing runs in the foreground.
- If library access is denied, or the media library cannot be listed, offers the system photo picker instead.
- Indexes with PP-OCRv6 medium (Simplified Chinese and English) and EmbeddingGemma 2 (text 270M + vision 170M, 768-d). Search fuses keyword hits and visual hits with reciprocal rank fusion.
- Names photos with Qwen3-VL-2B-Instruct when those files are present. The model is loaded for a label and closed afterward. It is not used while searching.
- Filters by file name and date even before any model is installed.
- Lists albums the phone already has. Face clustering is not linked yet.

Indexing pauses when the app is backgrounded and continues when you return, so Android is less likely to kill a long run silently. On a Kirin 9010S, vision labeling can take tens of seconds per photo. The grid stays usable.

## Huawei and other Android phones without Google Play

Albumseek is a normal Android APK. It does not use Google Play services, Firebase, ML Kit, or Google Sign-In, so it can be sideloaded onto Huawei phones and other AOSP-based devices.

- Photos are read with [photo_manager](https://pub.dev/packages/photo_manager), which uses Android's MediaStore. That is the same library the system gallery shows.
- The fallback picker uses `image_picker`. On Android 15 and earlier that is an `ACTION_GET_CONTENT` intent, which works when the system photo picker is missing. On Android 16 the plugin uses the platform photo picker. Albumseek does not enable the Play services photo-picker backport, and the app manifest removes the plugin's optional Play services metadata entry.
- Install this APK on Huawei phones that still run Android apps (EMUI, and HarmonyOS versions with the Android runtime). HarmonyOS NEXT does not install Android APKs.
- Minimum Android version is API 30. LiteRT, which runs EmbeddingGemma 2, requires it. A Huawei nova 15 Ultra is newer than that.
- Inference uses the CPU. ONNX Runtime is pinned to its CPU provider. LiteRT and llama.cpp are asked for CPU as well, so a missing GPU or NNAPI driver is not a dead end.

Permissions:

| Permission | When |
| --- | --- |
| `READ_MEDIA_IMAGES` | Android 13 and newer, to list images |
| `READ_MEDIA_VISUAL_USER_SELECTED` | Android 14 and newer, when the user grants only selected photos |
| `READ_EXTERNAL_STORAGE` (max SDK 32) | Android 12 and older |
| `INTERNET` | Downloading model files only. Search, OCR, and labeling do not call a server |

Debug and profile builds also use `INTERNET` so the Flutter tool can attach.

## Bootstrap

This project was built with Flutter 3.50.1 stable (Dart 3.14.0), JDK 17 or newer (tested with 21), and Android SDK platform 36.

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) and the Android SDK command-line tools.
2. Set `ANDROID_HOME` to the SDK directory. The SDK needs platform 36, a current build-tools package, and platform-tools.
3. From this repository:

```bash
flutter pub get
```

`flutter doctor` should report a usable Android toolchain before you build.

## Run on a device or emulator

Enable USB debugging, then:

```bash
flutter run
```

A release-mode install, which matches the sideload build more closely:

```bash
flutter run --release
```

On first launch, choose **Allow photo access**. Android 14 can grant all photos or only selected photos. Selected photos appear in the grid, and **Choose more** reopens that picker. **Choose photos** remains available when library access is off.

## Build a sideload APK

The arm64 release build for a Huawei phone:

```bash
flutter build apk --release --split-per-abi
```

That writes `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Install it over USB:

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Or copy that APK onto the phone and open it from the file manager. Allow installation from that source when Android asks.

A universal APK, if you need one, is `flutter build apk --release` and `build/app/outputs/flutter-apk/app-release.apk`.

The release APK is signed with the debug keystore so it can be installed immediately. Before sharing it more widely, replace `signingConfig` in `android/app/build.gradle.kts` with a keystore you control.

`photo_manager` still applies the Kotlin Gradle plugin, so the build prints a warning about a future Flutter change. The APK is produced anyway.

## Models

Weights are not inside the APK. After install, open **Models** on the library screen and download or import each file. An import is accepted when the file name matches. OCR files are checked against the publisher SHA-256.

| File | Role | License | Source |
| --- | --- | --- | --- |
| `PP-OCRv6_det_medium.onnx` | Text detection, medium | Apache-2.0 | [RapidAI/RapidOCR v3.9.2](https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/det/PP-OCRv6_det_medium.onnx) |
| `PP-OCRv6_rec_medium.onnx` | Recognition, Simplified Chinese and English | Apache-2.0 | [RapidAI/RapidOCR v3.9.2](https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/rec/PP-OCRv6_rec_medium.onnx) |
| `ppocrv6_dict.txt` | 18708-character dictionary | Apache-2.0 | [RapidAI/RapidOCR v3.9.2](https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/paddle/PP-OCRv6/rec/PP-OCRv6_rec_medium/ppocrv6_dict.txt) |
| `embeddinggemma-2-text-vision-440m.litertlm` | EmbeddingGemma 2, text 270M + vision 170M, 768-d | Apache-2.0 | [litert-community export of google/embeddinggemma-2](https://huggingface.co/litert-community/embeddinggemma-2-text-vision-440m-litert-lm/blob/e301f74d5551b0c2641bd5cb4652a76239d5c5f8/embeddinggemma-2-text-vision-440m.litertlm) |
| `Qwen3VL-2B-Instruct-Q4_K_M.gguf` | Short Chinese labels | Apache-2.0 | [Qwen/Qwen3-VL-2B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF) |
| `mmproj-Qwen3VL-2B-Instruct-F16.gguf` | Vision projector for that GGUF | Apache-2.0 | same Qwen repository |

OCR runs on ONNX Runtime's CPU provider. Embeddings run on LiteRT's CPU path. Labels run on llama.cpp's CPU backend, and that model is closed after each photo. The Vulkan ggml library is not packaged. Keyword text is stored in SQLite FTS5 as CJK bigrams. Vectors are 768-d in sqlite-vec 0.1.9 (MIT or Apache-2.0). The Android `libsqlite_vec.so` builds from that release are in `android/app/src/main/jniLibs`, because the current pub.dev plugin does not include its C source. Keyword and visual hits are fused with reciprocal rank fusion. There is no cloud reranker and no Qwen3-Embedding-8B.

Face grouping is declared in `lib/src/engine/face_index.dart` and is not implemented. The intended stack is MediaPipe or OpenCV YuNet plus AdaFace (MIT). InsightFace buffalo and antelope packs are not used.

Without these files, the grid, file-name filter, date filter, and albums still work. **Index** starts once the OCR and EmbeddingGemma files are on the phone. Labels wait until both Qwen files are present.

## iOS

`ios/` is the default Flutter project so the same UI can be reused later. This version does not set up signing, CocoaPods, or an iOS build. iOS comes after the Android app is proven on a phone.

## License

[Apache License 2.0](LICENSE).
