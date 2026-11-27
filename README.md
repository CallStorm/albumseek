# albumseek

On-device photo search for a person's camera roll. OCR, embeddings, and short labels run on the phone after you download the model files. The library grid still opens when those files are missing.

## What this version does

- Asks for permission to read images stored on the phone, and explains what to do when that permission is denied.
- Shows a scrollable grid of those images while indexing runs in the foreground.
- If library access is denied, or the media library cannot be listed, offers the system photo picker instead.
- Indexes with PP-OCRv6 medium (Simplified Chinese and English) and EmbeddingGemma 2 (text 270M + vision 170M, 768-d). Search fuses keyword hits and visual hits with reciprocal rank fusion.
- Names photos with Qwen3-VL-2B-Instruct when those files are present. The model is loaded once for the naming pass and closed when the pass ends, you pause, or the app is backgrounded. **Skip naming** on the library banner turns that pass off. Naming is not used while searching.
- Groups faces with OpenCV YuNet and AdaFace after those two files are downloaded. Both stay loaded for the faces pass, then unload. People, including group photos, are listed under Collections. Embeddings already stored are reused on the next index.
- Reads mainland ID cards (身份证), household registers (户口本), and similar labeled forms from the PP-OCRv6 text. PaddleOCR-VL-1.6 runs only when that text already parses as one of those documents, or contains 公民身份号码, 身份证, 居民户口簿, 户口簿, or 户口本. A stray 证, 户, or 表 does not load it. When it does run, it is loaded once for those photos and then closed.
- Filters by file name and date even before any model is installed. Document fields are added to the same keyword index.
- Lists albums the phone already has.

The library banner shows the active pass and that pass's own count, for example `Indexing · reading text 12 / 340`. After OCR and embeddings finish, it says search can be used while faces, documents, and naming continue. Indexing pauses when the app is backgrounded and unloads the model it was holding. On a Kirin 9010S, naming can still take a long time even with Qwen kept loaded; skip it if you only want search.

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
| `INTERNET` | Downloading model files only. Search, OCR, faces, documents, and labeling do not call a server |

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
| `face_detection_yunet_2023mar.onnx` | Face detection, about 233 KB | MIT | [opencv/face_detection_yunet](https://huggingface.co/opencv/face_detection_yunet) and [opencv_zoo](https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet) |
| `adaface_ir_18.onnx` | AdaFace IR-18, WebFace4M, 512-d, 96,105,345 bytes | MIT | [yakhyo/adaface-onnx](https://github.com/yakhyo/adaface-onnx/releases/download/weights/adaface_ir_18.onnx), export of [mk-minchul/AdaFace](https://github.com/mk-minchul/AdaFace) (MIT). Mirror: [yakhyo/uniface-weights](https://huggingface.co/yakhyo/uniface-weights) |
| `paddleocr-vl-1-6-Q4_K_M.gguf` | PaddleOCR-VL-1.6 0.9B decoder, Q4_K_M, about 300 MB | Apache-2.0 | [moonbox-dev/PaddleOCR-VL-1.6-GGUF](https://huggingface.co/moonbox-dev/PaddleOCR-VL-1.6-GGUF). Base model: [PaddlePaddle/PaddleOCR-VL-1.6](https://huggingface.co/PaddlePaddle/PaddleOCR-VL-1.6) (Apache-2.0) |
| `mmproj-paddleocr-vl-1-6-F16.gguf` | PaddleOCR-VL-1.6 vision encoder, F16, about 880 MB | Apache-2.0 | same moonbox-dev repository |
| `Qwen3VL-2B-Instruct-Q4_K_M.gguf` | Short Chinese labels | Apache-2.0 | [Qwen/Qwen3-VL-2B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF) |
| `mmproj-Qwen3VL-2B-Instruct-F16.gguf` | Vision projector for that GGUF | Apache-2.0 | same Qwen repository |

OCR, YuNet, and AdaFace run on ONNX Runtime's CPU provider. Embeddings run on LiteRT's CPU path. Labels and document vision run on llama.cpp's CPU backend. Only one of those large models is loaded at a time, and it is closed before the next stage. The Vulkan ggml library is not packaged. Keyword text, including document fields, is stored in SQLite FTS5 as CJK bigrams. Photo vectors are 768-d in sqlite-vec 0.1.9 (MIT or Apache-2.0). Face vectors are 512-d JSON next to the photo id. The Android `libsqlite_vec.so` builds from that release are in `android/app/src/main/jniLibs`, because the current pub.dev plugin does not include its C source. Keyword and visual hits are fused with reciprocal rank fusion. There is no cloud reranker and no Qwen3-Embedding-8B.

InsightFace buffalo and antelope packs are not used. Their default license is non-commercial. YuNet is the OpenCV face detector (MIT). AdaFace weights are the official IR-18 WebFace4M export (MIT).

PaddleOCR-VL stays in this build. The official GGUF repository publishes the unquantized decoder and projector, which are too large to keep resident on a 12 GB phone. The Q4_K_M decoder (300,218,624 bytes) plus F16 projector (880,415,392 bytes) above is the same Apache-2.0 model, quantized. The llama.cpp build linked by this app (llamadart 0.20.8) includes the `paddleocr` architecture. It is loaded once, only for photos whose PP-OCRv6 text parses as an ID card, household register, or labeled form, or that contain 公民身份号码, 身份证, 居民户口簿, 户口簿, or 户口本. It is not loaded for an ordinary caption that merely contains 证, 户, or 表. If that GGUF fails to load, the PP-OCRv6 parse still stores the fields. The feature is not dropped.

PP-OCRv6 stays loaded for the whole text pass, then EmbeddingGemma 2 stays loaded for the whole embedding pass. YuNet and AdaFace stay loaded together for the faces pass. Qwen3-VL stays loaded for the naming pass. Each of those is closed before the next pass. Search does not keep Qwen or PaddleOCR-VL in memory.

Without these files, the grid, file-name filter, date filter, and albums still work. **Index** starts once the OCR and EmbeddingGemma files are on the phone. Faces start once YuNet and AdaFace are both present. Document fields from OCR start with the search models; the PaddleOCR-VL pass starts once both of its files are present. Labels wait until both Qwen files are present. Open **Models**, download or import the files you want, then return to the library and let indexing continue. People and documents appear under **Collections**. A person's page includes group photos. Opening a document photo shows the extracted fields, and those fields match keyword search.

## iOS

`ios/` is the default Flutter project so the same UI can be reused later. This version does not set up signing, CocoaPods, or an iOS build. iOS comes after the Android app is proven on a phone.

## License

[Apache License 2.0](LICENSE).
