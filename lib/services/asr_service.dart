import 'package:flutter/services.dart';

// ASR bridge for offline speech recognition.
//
// Day 5 evaluation: try whisper_kit Flutter package first. If it has stable
// Android support, replace this MethodChannel bridge with the package API.
// If iOS-only or broken, this bridge routes to whisper.cpp JNI via WhisperBridge.kt.
//
// Until Day 5: this service is stubbed — text input is used for Days 1-4.
class AsrService {
  static const _channel = MethodChannel('com.chwcopilot.app/whisper');

  bool _loaded = false;

  Future<void> loadModel(String modelPath) async {
    await _channel.invokeMethod<void>('loadModel', {'path': modelPath});
    _loaded = true;
  }

  // Returns transcript string. Confidence is returned by the native side;
  // if < 0.4, caller should show "Did you mean?" correction prompt.
  Future<AsrResult> transcribe(String audioPath) async {
    assert(_loaded, 'loadModel() must be called before transcribe()');
    final result = await _channel.invokeMethod<Map>('transcribe', {
      'path': audioPath,
    });
    return AsrResult(
      transcript: result?['transcript'] as String? ?? '',
      confidence: (result?['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Explicit dispose — called BEFORE loading LiteRT-LM (sequential model loading, D4/D9).
  // Frees native whisper.cpp session. await this before calling LlmService.loadModel().
  Future<void> dispose() async {
    if (!_loaded) return;
    await _channel.invokeMethod<void>('dispose');
    _loaded = false;
  }
}

class AsrResult {
  final String transcript;
  final double confidence; // 0.0 – 1.0

  const AsrResult({required this.transcript, required this.confidence});

  bool get isLowConfidence => confidence < 0.4;
}
