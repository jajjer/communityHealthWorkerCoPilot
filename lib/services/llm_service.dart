import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/protocol.dart';

// LiteRT-LM bridge via MethodChannel.
// Day 1 spike: confirm that 'loadModel' returns without error using Gemma 4 E2B.
// If LiteRT-LM Gemma 4 bindings are missing by EOD Day 1, swap LiteRtBridge.kt
// for MediaPipeBridge.kt — this Dart service is unchanged.
class LlmService {
  static const _channel = MethodChannel('com.chwcopilot.app/litert');
  static const _maxRetries = 3;

  bool _loaded = false;

  Future<void> loadModel(String modelPath) async {
    await _channel.invokeMethod<void>('loadModel', {'path': modelPath});
    _loaded = true;
  }

  // Validate-and-retry loop (D11): LiteRT-LM does not expose grammar sampling.
  // Parse JSON output; retry up to 3× on malformed result.
  // Worst case: 3 × ~3s = ~9s extra latency. Acceptable for demo.
  Future<FunctionCall?> runFunctionCall(String prompt) async {
    assert(_loaded, 'loadModel() must be called before runFunctionCall()');

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final raw = await _rawInference(prompt, attempt);
      final call = _parseFunctionCall(raw);
      if (call != null) return call;
    }
    return null; // All retries exhausted → caller falls back to "refer to clinic"
  }

  // Second inference: feed protocol back in, get plain-language verdict
  Future<String> runVerdictInference(String prompt) async {
    assert(_loaded, 'loadModel() must be called before runVerdictInference()');
    return await _rawInference(prompt, 0);
  }

  // Explicit dispose — Dart GC does not free the C++ LiteRT-LM session.
  // Call this before loading whisper (sequential model loading, D9).
  Future<void> dispose() async {
    if (!_loaded) return;
    await _channel.invokeMethod<void>('dispose');
    _loaded = false;
  }

  Future<String> _rawInference(String prompt, int attempt) async {
    final retryHint = attempt > 0
        ? '\n\nIMPORTANT: Your previous response was not valid JSON. Respond ONLY with the JSON function call, no other text.'
        : '';
    final result = await _channel.invokeMethod<String>(
      'runInference',
      {'prompt': '$prompt$retryHint'},
    );
    return result ?? '';
  }

  FunctionCall? _parseFunctionCall(String raw) {
    // Strip markdown code fences if present
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'```(?:json)?'), '').trim();
    }

    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      if (json['function'] != 'query_protocol') return null;
      return FunctionCall.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  // Prompt used for the first inference (transcript → function call)
  static String functionCallPrompt(String transcript) => '''
You are chwCoPilot, a clinical decision support system for Community Health Workers.
Given a symptom description, call the query_protocol function with the correct parameters.

Available conditions (use EXACTLY one of these strings):
malaria_uncomplicated, malaria_severe, pneumonia_mild, pneumonia_severe,
diarrhea_mild, diarrhea_severe, severe_acute_malnutrition, moderate_acute_malnutrition,
measles_mild, measles_complicated, tuberculosis_suspicion, hiv_aids_symptomatic,
neonatal_sepsis, neonatal_jaundice, fever_without_source, acute_respiratory_infection,
skin_infection, eye_infection, wound_trauma, pregnancy_emergency

Respond ONLY with this JSON, nothing else:
{"function":"query_protocol","parameters":{"condition":"<condition>","age_group":"<neonate|infant|child|adult>","severity":"<mild|moderate|severe>","symptom_flags":["<symptom>"]}}

CHW description: $transcript
''';

  // Prompt used for second inference (protocol → triage verdict text)
  static String verdictPrompt(Protocol protocol, String transcript) => '''
You are chwCoPilot. A CHW described: "$transcript"

Clinical protocol (${protocol.source}):
Verdict: ${protocol.verdict.value}
Steps:
${protocol.steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Respond in plain language the CHW can understand. Be direct and brief. State the verdict first.
''';
}
