package com.chwcopilot.chw_copilot

import android.util.Log

// ASR bridge — Day 5-6.
//
// Before implementing JNI: evaluate the 'whisper_kit' Flutter package on Day 5.
// If it has stable Android support, delete this file and use the package instead.
// If iOS-only or broken, implement this file with whisper.cpp JNI bindings.
//
// whisper.cpp JNI setup (if needed):
//   1. Copy whisper.cpp + whisper.h to android/app/src/main/cpp/
//   2. Create CMakeLists.txt linking the native lib
//   3. Add externalNativeBuild to android/app/build.gradle
//   4. Implement extern "C" JNI functions in whisper_jni.cpp
//
// Until Day 5: stub returns a hardcoded Swahili transcript for UI testing.

private const val TAG = "WhisperBridge"

class WhisperBridge {

    fun loadModel(path: String, onSuccess: () -> Unit, onError: (Exception) -> Unit) {
        Log.d(TAG, "STUB loadModel — implement with whisper.cpp JNI on Day 5-6")
        onSuccess()
    }

    fun transcribe(
        audioPath: String,
        onSuccess: (transcript: String, confidence: Float) -> Unit,
        onError: (Exception) -> Unit
    ) {
        Log.d(TAG, "STUB transcribe — returning hardcoded Swahili transcript")
        // "child has rash and fever" in Swahili — exercises the measles triage path
        onSuccess("mtoto ana upele na homa", 0.85f)
    }

    fun dispose() {
        Log.d(TAG, "STUB dispose")
    }
}
