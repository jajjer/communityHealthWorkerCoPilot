import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/protocol.dart';
import '../models/triage_result.dart';
import 'asr_service.dart';
import 'llm_service.dart';
import 'protocol_db.dart';

// Orchestrates the full patient encounter:
// 1. ASR: audio file → transcript (whisper.cpp, ~3-4s)
// 2. ASR dispose (explicit — D9)
// 3. LLM load (Gemma 4 E2B, ~1-2s cold start)
// 4. First inference: transcript → function call JSON (validate+retry, ~2-3s)
// 5. Protocol cache lookup: O(1), no SQLite I/O
// 6. Second inference: protocol → triage verdict text (~2-3s)
// 7. LLM dispose
// 8. Audit log write
class TriageEngine {
  final ProtocolDb _db;
  final LlmService _llm;
  final AsrService _asr;

  // Model paths — set these to the actual paths on device
  static const _llmModelPath = '/data/local/tmp/gemma4_e2b_int4.litert';
  static const _asrModelPath = '/data/local/tmp/whisper_small.bin';

  TriageEngine({
    required ProtocolDb db,
    required LlmService llm,
    required AsrService asr,
  })  : _db = db,
        _llm = llm,
        _asr = asr;

  // Run a complete triage from a recorded audio file.
  // Emits progress events via [onStep] for the Analyzing screen.
  Future<TriageResult> run(
    String audioPath, {
    required void Function(AnalysisStep) onStep,
  }) async {
    try {
      // Step 1: ASR
      onStep(const StepTranscribing());
      await _asr.loadModel(_asrModelPath);
      final asrResult = await _asr.transcribe(audioPath);

      // Explicit dispose before LLM load (D9 — sequential model loading)
      await _asr.dispose();

      onStep(StepTranscribed(asrResult.transcript));

      // Step 2: LLM first inference → function call
      onStep(const StepQueryingProtocol());
      await _llm.loadModel(_llmModelPath);

      final prompt = LlmService.functionCallPrompt(asrResult.transcript);
      final call = await _llm.runFunctionCall(prompt);

      if (call == null) {
        await _llm.dispose();
        return TriageUnclearCondition(
          transcript: asrResult.transcript,
          reason: 'Could not match a clinical condition after 3 attempts',
        );
      }

      // Step 3: Protocol cache lookup (O(1))
      final protocol = _db.lookup(call.condition, call.ageGroup, call.severity);
      if (protocol == null) {
        await _llm.dispose();
        return TriageUnclearCondition(
          transcript: asrResult.transcript,
          reason: 'Condition not in offline protocols',
        );
      }

      // Step 4: Second inference → plain-language verdict
      onStep(StepGeneratingVerdict(call));
      final verdictPrompt = LlmService.verdictPrompt(protocol, asrResult.transcript);
      final verdictText = await _llm.runVerdictInference(verdictPrompt);
      await _llm.dispose();

      // Step 5: GPS + audit log
      final pos = await _getPosition();
      final timestamp = DateTime.now();

      await _db.logCase(
        call: call,
        verdict: protocol.verdict,
        transcript: asrResult.transcript,
        timestamp: timestamp,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );

      onStep(const StepComplete());

      return TriageSuccess(
        protocol: protocol,
        transcript: asrResult.transcript,
        functionCall: call,
        conditionLabel: _conditionLabel(call.condition),
        verdictText: verdictText,
        timestamp: timestamp,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );
    } catch (e) {
      await _llm.dispose();
      await _asr.dispose();
      return TriageError('Unexpected error: $e');
    }
  }

  // Text-only path for Days 1-4 while ASR is not yet integrated.
  Future<TriageResult> runText(
    String description, {
    required void Function(AnalysisStep) onStep,
  }) async {
    try {
      onStep(StepTranscribed(description));
      onStep(const StepQueryingProtocol());

      await _llm.loadModel(_llmModelPath);
      final call = await _llm.runFunctionCall(
        LlmService.functionCallPrompt(description),
      );

      if (call == null) {
        await _llm.dispose();
        return TriageUnclearCondition(
          transcript: description,
          reason: 'Could not match condition after 3 attempts',
        );
      }

      final protocol = _db.lookup(call.condition, call.ageGroup, call.severity);
      if (protocol == null) {
        await _llm.dispose();
        return TriageUnclearCondition(
          transcript: description,
          reason: 'Condition not in offline protocols',
        );
      }

      onStep(StepGeneratingVerdict(call));
      final verdictText = await _llm.runVerdictInference(
        LlmService.verdictPrompt(protocol, description),
      );
      await _llm.dispose();

      final timestamp = DateTime.now();
      final pos = await _getPosition();
      await _db.logCase(
        call: call,
        verdict: protocol.verdict,
        transcript: description,
        timestamp: timestamp,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );

      onStep(const StepComplete());

      return TriageSuccess(
        protocol: protocol,
        transcript: description,
        functionCall: call,
        conditionLabel: _conditionLabel(call.condition),
        verdictText: verdictText,
        timestamp: timestamp,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );
    } catch (e) {
      await _llm.dispose();
      return TriageError('Error: $e');
    }
  }

  Future<Position?> _getPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String _conditionLabel(Condition c) {
    return switch (c) {
      Condition.malariaUncomplicated => 'Uncomplicated Malaria',
      Condition.malariaSevere => 'Severe Malaria',
      Condition.pneumoniaMild => 'Mild Pneumonia',
      Condition.pneumoniaSevere => 'Severe Pneumonia',
      Condition.diarrheaMild => 'Diarrhea with Mild Dehydration',
      Condition.diarrheaSevere => 'Severe Diarrhea',
      Condition.severeAcuteMalnutrition => 'Severe Acute Malnutrition (SAM)',
      Condition.moderateAcuteMalnutrition => 'Moderate Acute Malnutrition (MAM)',
      Condition.measlesMild => 'Mild Measles',
      Condition.measlesComplicated => 'Complicated Measles',
      Condition.tuberculosisSuspicion => 'TB Suspicion',
      Condition.hivAidsSymptomatic => 'HIV/AIDS Symptoms',
      Condition.neonatalSepsis => 'Neonatal Sepsis',
      Condition.neonatalJaundice => 'Neonatal Jaundice',
      Condition.feverWithoutSource => 'Fever (No Source)',
      Condition.acuteRespiratoryInfection => 'Acute Respiratory Infection',
      Condition.skinInfection => 'Skin Infection',
      Condition.eyeInfection => 'Eye Infection',
      Condition.woundTrauma => 'Wound / Trauma',
      Condition.pregnancyEmergency => 'Pregnancy Emergency',
    };
  }
}
