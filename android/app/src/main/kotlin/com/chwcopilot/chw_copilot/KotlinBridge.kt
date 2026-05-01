package com.chwcopilot.chw_copilot

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

// Cloud bridge for Days 1-4. Sends prompts to the Gemini API using native function calling.
// Swap for LiteRtBridge(this) in MainActivity once the Day 1 LiteRT-LM spike passes.
//
// API key: set GEMINI_API_KEY in android/local.properties (gitignored).

private const val TAG = "KotlinBridge"
private const val MODEL = "gemma-4-31b-it"
private const val BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
private const val MUAC_PROMPT = """You are analyzing a MUAC (Mid-Upper Arm Circumference) tape photo for a community health worker.
Read the measurement where the tape meets the indicator mark and respond in exactly this format:
MEASUREMENT: X.X cm
ZONE: red
STATUS: Severe Acute Malnutrition

Color zones: red = SAM (under 11.5 cm), yellow = MAM (11.5 to 12.5 cm), green = normal (over 12.5 cm)
Replace the example values with what you see in the image."""

class KotlinBridge(private val context: Context) : LlmBridge {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val scope = CoroutineScope(Dispatchers.IO)

    override fun loadModel(path: String, onSuccess: () -> Unit, onError: (Exception) -> Unit) {
        if (BuildConfig.GEMINI_API_KEY.isEmpty()) {
            onError(IllegalStateException("GEMINI_API_KEY not set in android/local.properties"))
            return
        }
        Log.d(TAG, "Cloud bridge ready — model: $MODEL")
        onSuccess()
    }

    override fun runInference(
        prompt: String,
        onSuccess: (String) -> Unit,
        onError: (Exception) -> Unit
    ) {
        scope.launch {
            try {
                val result = if (prompt.contains("query_protocol")) {
                    runFunctionCallInference(prompt)
                } else {
                    runTextInference(prompt)
                }
                withContext(Dispatchers.Main) { onSuccess(result) }
            } catch (e: Exception) {
                Log.e(TAG, "Inference failed", e)
                withContext(Dispatchers.Main) { onError(e) }
            }
        }
    }

    override fun dispose() {
        Log.d(TAG, "Cloud bridge dispose — no-op")
    }

    override fun analyzeImage(
        imageBytes: ByteArray,
        mimeType: String,
        onSuccess: (String) -> Unit,
        onError: (Exception) -> Unit,
    ) {
        scope.launch {
            try {
                val base64 = android.util.Base64.encodeToString(imageBytes, android.util.Base64.NO_WRAP)
                val body = JSONObject().apply {
                    put("contents", JSONArray().put(JSONObject().apply {
                        put("role", "user")
                        put("parts", JSONArray().apply {
                            put(JSONObject().put("text", MUAC_PROMPT))
                            put(JSONObject().apply {
                                put("inline_data", JSONObject().apply {
                                    put("mime_type", mimeType)
                                    put("data", base64)
                                })
                            })
                        })
                    }))
                }
                val text = extractText(post(body))
                withContext(Dispatchers.Main) { onSuccess(text) }
            } catch (e: Exception) {
                Log.e(TAG, "Image analysis failed", e)
                withContext(Dispatchers.Main) { onError(e) }
            }
        }
    }

    // Forces the model to call query_protocol via native function calling.
    // Gemini response shape: candidates[0].content.parts[0].functionCall.{name, args}
    // Dart FunctionCall.fromJson() expects: {"function":"query_protocol","parameters":{...}}
    private fun runFunctionCallInference(prompt: String): String {
        val body = JSONObject().apply {
            put("contents", JSONArray().put(userMessage(prompt)))
            put("tools", JSONArray().put(JSONObject().apply {
                put("functionDeclarations", JSONArray().put(queryProtocolTool()))
            }))
            put("toolConfig", JSONObject().apply {
                put("functionCallingConfig", JSONObject().apply {
                    put("mode", "ANY")
                    put("allowedFunctionNames", JSONArray().put("query_protocol"))
                })
            })
        }

        val response = post(body)
        return translateFunctionCall(response)
    }

    // Plain text generation for the verdict inference (second LLM call).
    private fun runTextInference(prompt: String): String {
        val body = JSONObject().apply {
            put("contents", JSONArray().put(userMessage(prompt)))
        }
        return extractText(post(body))
    }

    private fun post(body: JSONObject): JSONObject {
        val url = "$BASE_URL/$MODEL:generateContent?key=${BuildConfig.GEMINI_API_KEY}"
        val request = Request.Builder()
            .url(url)
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .build()

        val response = client.newCall(request).execute()
        val responseBody = response.body?.string() ?: throw RuntimeException("Empty API response")
        if (!response.isSuccessful) {
            throw RuntimeException("Gemini API ${response.code}: $responseBody")
        }
        return JSONObject(responseBody)
    }

    private fun translateFunctionCall(response: JSONObject): String {
        val fc = response
            .getJSONArray("candidates").getJSONObject(0)
            .getJSONObject("content")
            .getJSONArray("parts").getJSONObject(0)
            .getJSONObject("functionCall")

        return JSONObject().apply {
            put("function", fc.getString("name"))
            put("parameters", fc.getJSONObject("args"))
        }.toString()
    }

    private fun extractText(response: JSONObject): String {
        return response
            .getJSONArray("candidates").getJSONObject(0)
            .getJSONObject("content")
            .getJSONArray("parts").getJSONObject(0)
            .getString("text")
    }

    private fun userMessage(text: String): JSONObject = JSONObject().apply {
        put("role", "user")
        put("parts", JSONArray().put(JSONObject().put("text", text)))
    }

    private fun queryProtocolTool(): JSONObject = JSONObject().apply {
        put("name", "query_protocol")
        put("description", "Look up the WHO/MSF clinical protocol for a condition")
        put("parameters", JSONObject().apply {
            put("type", "object")
            put("properties", JSONObject().apply {
                put("condition", JSONObject().apply {
                    put("type", "string")
                    put("enum", JSONArray().apply {
                        listOf(
                            "malaria_uncomplicated", "malaria_severe",
                            "pneumonia_mild", "pneumonia_severe",
                            "diarrhea_mild", "diarrhea_severe",
                            "severe_acute_malnutrition", "moderate_acute_malnutrition",
                            "measles_mild", "measles_complicated",
                            "tuberculosis_suspicion", "hiv_aids_symptomatic",
                            "neonatal_sepsis", "neonatal_jaundice",
                            "fever_without_source", "acute_respiratory_infection",
                            "skin_infection", "eye_infection",
                            "wound_trauma", "pregnancy_emergency"
                        ).forEach { put(it) }
                    })
                })
                put("age_group", JSONObject().apply {
                    put("type", "string")
                    put("enum", JSONArray().apply {
                        listOf("neonate", "infant", "child", "adult").forEach { put(it) }
                    })
                })
                put("severity", JSONObject().apply {
                    put("type", "string")
                    put("enum", JSONArray().apply {
                        listOf("mild", "moderate", "severe").forEach { put(it) }
                    })
                })
                put("symptom_flags", JSONObject().apply {
                    put("type", "array")
                    put("items", JSONObject().put("type", "string"))
                })
            })
            put("required", JSONArray().apply {
                listOf("condition", "age_group", "severity", "symptom_flags").forEach { put(it) }
            })
        })
    }
}
