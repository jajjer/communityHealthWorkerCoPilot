package com.chwcopilot.chw_copilot

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

// DAY 1 SPIKE — this file determines whether we proceed with LiteRT-LM or fall back to MediaPipe.
//
// Add one of these to android/app/build.gradle dependencies:
//
//   OPTION A — LiteRT-LM (primary, D1):
//   implementation 'com.google.ai.edge.litert:litert-lm:1.0.0-beta1'
//
//   OPTION B — MediaPipe (Day 1 fallback, D13):
//   implementation 'com.google.mediapipe:tasks-genai:0.10.22'
//
// If Option A compiles and loadModel() returns without error on your dev phone → LiteRT-LM confirmed.
// If Option A fails to resolve or crashes on loadModel() → swap to Option B implementation below.
//
// DO NOT spend more than EOD Day 1 debugging LiteRT-LM bindings.

private const val TAG = "LiteRtBridge"

class LiteRtBridge {
    private val scope = CoroutineScope(Dispatchers.IO)

    // -------------------------------------------------------------------------
    // OPTION A: LiteRT-LM implementation
    // Uncomment when 'com.google.ai.edge.litert:litert-lm' resolves.
    // -------------------------------------------------------------------------
    // private var session: com.google.ai.edge.litert.lm.LlmInferenceSession? = null
    //
    // fun loadModel(path: String, onSuccess: () -> Unit, onError: (Exception) -> Unit) {
    //     scope.launch {
    //         try {
    //             val options = com.google.ai.edge.litert.lm.LlmInference.LlmInferenceOptions.builder()
    //                 .setModelPath(path)
    //                 .setMaxTokens(512)
    //                 .setTopK(40)
    //                 .setTemperature(0.1f)  // Low temp for structured JSON output
    //                 .build()
    //             val inference = com.google.ai.edge.litert.lm.LlmInference.createFromOptions(
    //                 applicationContext, options
    //             )
    //             session = inference.createSession()
    //             onSuccess()
    //         } catch (e: Exception) {
    //             Log.e(TAG, "LiteRT-LM loadModel failed", e)
    //             onError(e)
    //         }
    //     }
    // }
    //
    // fun runInference(prompt: String, onSuccess: (String) -> Unit, onError: (Exception) -> Unit) {
    //     scope.launch {
    //         try {
    //             val result = session!!.generateResponse(prompt)
    //             onSuccess(result)
    //         } catch (e: Exception) {
    //             Log.e(TAG, "LiteRT-LM inference failed", e)
    //             onError(e)
    //         }
    //     }
    // }
    //
    // fun dispose() {
    //     session?.close()
    //     session = null
    //     Log.d(TAG, "LiteRT-LM session disposed")
    // }

    // -------------------------------------------------------------------------
    // OPTION B: MediaPipe LLM Inference API fallback (D13)
    // Uncomment if LiteRT-LM fails Day 1 spike. Uses Gemma 3 as interim model.
    // -------------------------------------------------------------------------
    // private var llmInference: com.google.mediapipe.tasks.genai.llminference.LlmInference? = null
    //
    // fun loadModel(path: String, onSuccess: () -> Unit, onError: (Exception) -> Unit) {
    //     scope.launch {
    //         try {
    //             val options = com.google.mediapipe.tasks.genai.llminference.LlmInference.LlmInferenceOptions.builder()
    //                 .setModelPath(path)
    //                 .setMaxTokens(512)
    //                 .build()
    //             llmInference = com.google.mediapipe.tasks.genai.llminference.LlmInference.createFromOptions(
    //                 context, options
    //             )
    //             onSuccess()
    //         } catch (e: Exception) {
    //             Log.e(TAG, "MediaPipe loadModel failed", e)
    //             onError(e)
    //         }
    //     }
    // }
    //
    // fun runInference(prompt: String, onSuccess: (String) -> Unit, onError: (Exception) -> Unit) {
    //     scope.launch {
    //         try {
    //             val result = llmInference!!.generateResponse(prompt)
    //             onSuccess(result)
    //         } catch (e: Exception) {
    //             Log.e(TAG, "MediaPipe inference failed", e)
    //             onError(e)
    //         }
    //     }
    // }
    //
    // fun dispose() {
    //     llmInference?.close()
    //     llmInference = null
    // }

    // -------------------------------------------------------------------------
    // STUB — active until Day 1 spike confirms which option to uncomment.
    // Returns a hardcoded valid function call JSON for UI testing.
    // -------------------------------------------------------------------------
    fun loadModel(path: String, onSuccess: () -> Unit, onError: (Exception) -> Unit) {
        Log.d(TAG, "STUB loadModel — replace with Option A or B after Day 1 spike")
        onSuccess()
    }

    fun runInference(prompt: String, onSuccess: (String) -> Unit, onError: (Exception) -> Unit) {
        Log.d(TAG, "STUB runInference — returning hardcoded measles example")
        // Returns valid JSON for the UI to exercise the full triage flow without a real model
        val stub = """{"function":"query_protocol","parameters":{"condition":"measles_mild","age_group":"child","severity":"moderate","symptom_flags":["fever","rash"]}}"""
        onSuccess(stub)
    }

    fun dispose() {
        Log.d(TAG, "STUB dispose")
    }
}
