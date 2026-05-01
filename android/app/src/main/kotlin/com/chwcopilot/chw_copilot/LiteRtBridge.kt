package com.chwcopilot.chw_copilot

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

// On-device Gemma 4 E2B inference via LiteRT-LM.
//
// To enable: swap MainActivity to use LiteRtBridge(this) instead of KotlinBridge(this).
//
// Model setup (one-time):
//   1. Download gemma-4-E2B-it.litertlm from:
//      https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm
//   2. adb push gemma-4-E2B-it.litertlm /data/local/tmp/
//
// The model is ~1.5GB. First initialize() call takes 5-10s.
// Subsequent inference calls: ~2-5s on mid-range Android.

private const val TAG = "LiteRtBridge"

class LiteRtBridge(private val context: Context) : LlmBridge {

    private var engine: com.google.ai.edge.litertlm.Engine? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    override fun loadModel(path: String, onSuccess: () -> Unit, onError: (Exception) -> Unit) {
        scope.launch {
            try {
                // CPU backend for emulator compatibility. On real hardware with GPU,
                // swap to Backend.GPU() for ~5-10x faster inference.
                val config = com.google.ai.edge.litertlm.EngineConfig(
                    modelPath = path,
                    backend = com.google.ai.edge.litertlm.Backend.CPU()
                )
                val e = com.google.ai.edge.litertlm.Engine(config)
                e.initialize()
                engine = e
                Log.d(TAG, "LiteRT-LM CPU engine initialized: $path")
                withContext(Dispatchers.Main) { onSuccess() }
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM loadModel failed", e)
                withContext(Dispatchers.Main) { onError(e) }
            }
        }
    }

    override fun runInference(
        prompt: String,
        onSuccess: (String) -> Unit,
        onError: (Exception) -> Unit
    ) {
        scope.launch {
            try {
                val e = engine ?: run {
                    withContext(Dispatchers.Main) {
                        onError(IllegalStateException("Model not loaded — call loadModel first"))
                    }
                    return@launch
                }
                val response = e.createConversation().use { conversation ->
                    conversation.sendMessage(prompt)
                }
                withContext(Dispatchers.Main) { onSuccess(response.toString()) }
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM inference failed", e)
                withContext(Dispatchers.Main) { onError(e) }
            }
        }
    }

    override fun dispose() {
        engine?.close()
        engine = null
        Log.d(TAG, "LiteRT-LM engine disposed")
    }
}
