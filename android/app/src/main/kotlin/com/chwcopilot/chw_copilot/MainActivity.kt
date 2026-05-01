package com.chwcopilot.chw_copilot

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var llmBridge: LlmBridge
    private lateinit var whisperBridge: WhisperBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Day 5+: swap to LiteRtBridge(this) once LiteRT-LM spike passes.
        //llmBridge = LiteRtBridge(this)
        llmBridge = KotlinBridge(this)
        whisperBridge = WhisperBridge()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chwcopilot.app/litert"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("path") ?: run {
                        result.error("INVALID_ARG", "path required", null)
                        return@setMethodCallHandler
                    }
                    llmBridge.loadModel(path,
                        onSuccess = { result.success(null) },
                        onError = { e -> result.error("LOAD_FAILED", e.message, null) }
                    )
                }
                "runInference" -> {
                    val prompt = call.argument<String>("prompt") ?: run {
                        result.error("INVALID_ARG", "prompt required", null)
                        return@setMethodCallHandler
                    }
                    llmBridge.runInference(prompt,
                        onSuccess = { text -> result.success(text) },
                        onError = { e -> result.error("INFERENCE_FAILED", e.message, null) }
                    )
                }
                "dispose" -> { llmBridge.dispose(); result.success(null) }
                "analyzeImage" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes") ?: run {
                        result.error("INVALID_ARG", "imageBytes required", null)
                        return@setMethodCallHandler
                    }
                    val mimeType = call.argument<String>("mimeType") ?: "image/jpeg"
                    llmBridge.analyzeImage(imageBytes, mimeType,
                        onSuccess = { text -> result.success(text) },
                        onError = { e -> result.error("ANALYZE_FAILED", e.message, null) }
                    )
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chwcopilot.app/whisper"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("path") ?: run {
                        result.error("INVALID_ARG", "path required", null)
                        return@setMethodCallHandler
                    }
                    whisperBridge.loadModel(path,
                        onSuccess = { result.success(null) },
                        onError = { e -> result.error("LOAD_FAILED", e.message, null) }
                    )
                }
                "transcribe" -> {
                    val path = call.argument<String>("path") ?: run {
                        result.error("INVALID_ARG", "path required", null)
                        return@setMethodCallHandler
                    }
                    whisperBridge.transcribe(path,
                        onSuccess = { transcript, confidence ->
                            result.success(mapOf("transcript" to transcript, "confidence" to confidence))
                        },
                        onError = { e -> result.error("TRANSCRIBE_FAILED", e.message, null) }
                    )
                }
                "dispose" -> { whisperBridge.dispose(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
}
