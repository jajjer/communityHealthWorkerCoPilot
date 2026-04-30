#!/bin/bash
# chwCoPilot — Day 1 setup
# Run this after installing Flutter SDK + Android Studio.
# https://docs.flutter.dev/get-started/install/macos/mobile-android

set -e

echo "=== chwCoPilot setup ==="

# 1. Generate Flutter boilerplate (build.gradle, settings.gradle, ios/, etc.)
#    --overwrite so generated files land, then we restore our custom files.
flutter create . \
  --project-name chw_copilot \
  --org com.chwcopilot \
  --platforms android \
  --overwrite

echo "Flutter boilerplate generated."

# 2. Our custom files take precedence — restore them after flutter create overwrites.
#    (flutter create overwrites lib/main.dart and android/app/src/main/kotlin/.../MainActivity.kt)
#    These are tracked in git, so just:
git checkout -- lib/ android/app/src/main/kotlin/ android/app/src/main/AndroidManifest.xml

echo "Custom files restored."

# 3. Install Dart dependencies
flutter pub get

echo "Dependencies installed."

# 4. Run unit tests (no device needed)
flutter test test/protocol_test.dart test/llm_service_test.dart

echo ""
echo "=== Day 1 spike checklist ==="
echo "1. Open android/app/build.gradle"
echo "2. Uncomment OPTION A (LiteRT-LM) under dependencies"
echo "3. Run: flutter run"
echo "4. Check logcat: 'STUB loadModel' means the bridge works, replace with real LiteRT-LM impl"
echo "5. If Option A fails to resolve: switch to OPTION B (MediaPipe) by EOD"
echo ""
echo "adb logcat -s LiteRtBridge:D WhisperBridge:D flutter:D"
