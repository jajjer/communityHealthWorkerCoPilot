package com.chwcopilot.chw_copilot

interface LlmBridge {
    fun loadModel(path: String, onSuccess: () -> Unit, onError: (Exception) -> Unit)
    fun runInference(prompt: String, onSuccess: (String) -> Unit, onError: (Exception) -> Unit)
    fun dispose()

    // Image analysis for MUAC tape reading. Cloud-only — on-device bridge returns unsupported.
    fun analyzeImage(
        imageBytes: ByteArray,
        mimeType: String,
        onSuccess: (String) -> Unit,
        onError: (Exception) -> Unit,
    ) {
        onError(UnsupportedOperationException("Image analysis requires cloud bridge"))
    }
}
