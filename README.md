# albumseek

On-device photo search for a person's camera roll. OCR, semantic search, people, and albums are meant to run on the phone. This version is the Android app shell and photo library. Listing photos, filtering them, and any later recognition stay on the device.

## What this version does

- Asks for permission to read images stored on the phone, and explains what to do when that permission is denied.
- Shows a scrollable grid of those images.
- If library access is denied, or the media library cannot be listed, offers the system photo picker instead.
- Filters the loaded library by file name and by date (today, 7 days, 30 days, this year).
- Lists albums the phone already has. People grouping is reserved for a later build.

File name and date are the only search in this version. Text inside photos and visual similarity are not searched yet.

## Huawei and other Android phones without Google Play

Albumseek is a normal Android APK. It does not use Google Play services, Firebase, ML Kit, or Google Sign-In, so it can be sideloaded onto Huawei phones and other AOSP-based devices.

- Photos are read with [photo_manager](https://pub.dev/packages/photo_manager), which uses Android's MediaStore. That is the same library the system gallery shows.
- The fallback picker uses `image_picker`. On Android 15 and earlier that is an `ACTION_GET_CONTENT` intent, which works when the system photo picker is missing. On Android 16 the plugin uses the platform photo picker. Albumseek does not enable the Play services photo-picker backport, and the app manifest removes the plugin's optional Play services metadata entry.
- Install this APK on Huawei phones that still run Android apps (EMUI, and HarmonyOS versions with the Android runtime). HarmonyOS NEXT does not install Android APKs.
- The minimum Android version is API 24 (Android 7).

Permissions, and nothing beyond them:

| Permission | When |
| --- | --- |
| `READ_MEDIA_IMAGES` | Android 13 and newer, to list images |
| `READ_MEDIA_VISUAL_USER_SELECTED` | Android 14 and newer, when the user grants only selected photos |
| `READ_EXTERNAL_STORAGE` (max SDK 32) | Android 12 and older |

Debug and profile builds also declare `INTERNET` so the Flutter tool can attach. The release APK does not need a network connection.

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

The command used to produce the release APK:

```bash
flutter build apk --release
```

`photo_manager` still applies the Kotlin Gradle plugin, so the build prints a warning about a future Flutter change. The APK is produced anyway.

The universal APK is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Install it over USB:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Or copy `app-release.apk` onto the phone and open it from the file manager. Allow installation from that source when Android asks.

Smaller per-ABI APKs, if you know the phone's architecture (Huawei phones in current use are arm64):

```bash
flutter build apk --release --split-per-abi
```

The release APK is signed with the debug keystore so it can be installed immediately. Before sharing it more widely, replace `signingConfig` in `android/app/build.gradle.kts` with a keystore you control.

## Where later on-device search plugs in

Model weights are not in this repository. The extension points are:

- `lib/src/engine/inference_backend.dart` — native inference (ONNX Runtime, MNN, llama.cpp, or MediaPipe / LiteRT)
- `lib/src/engine/local_index.dart` — sqlite-vec for vectors and SQLite FTS5 with Chinese tokenization
- `lib/src/engine/engine_plan.dart` — the runtime list those files are meant to host

Planned work, not implemented here: on-device OCR, image and text embeddings, keyword search, reranking, album names, and face grouping. Those models are intended to stay on the phone.

## iOS

`ios/` is the default Flutter project so the same UI can be reused later. This version does not set up signing, CocoaPods, or an iOS build. iOS comes after the Android app is proven on a phone.

## License

[Apache License 2.0](LICENSE).
