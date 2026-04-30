import 'protocol.dart';

sealed class TriageResult {
  const TriageResult();
}

class TriageSuccess extends TriageResult {
  final Protocol protocol;
  final String transcript;         // What the CHW said
  final FunctionCall functionCall; // The tool call Gemma 4 made (audit trail)
  final String conditionLabel;     // Human-readable, in selected language
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;

  const TriageSuccess({
    required this.protocol,
    required this.transcript,
    required this.functionCall,
    required this.conditionLabel,
    required this.timestamp,
    this.latitude,
    this.longitude,
  });
}

class TriageUnclearCondition extends TriageResult {
  final String transcript;
  final String reason; // Why we couldn't triage
  const TriageUnclearCondition({required this.transcript, required this.reason});
}

class TriageError extends TriageResult {
  final String message;
  const TriageError(this.message);
}

// Progress events emitted during the analyzing screen
sealed class AnalysisStep {
  final String label;
  const AnalysisStep(this.label);
}
class StepTranscribing extends AnalysisStep { const StepTranscribing() : super('Transcribing audio…'); }
class StepTranscribed extends AnalysisStep {
  final String transcript;
  const StepTranscribed(this.transcript) : super('Audio transcribed');
}
class StepQueryingProtocol extends AnalysisStep { const StepQueryingProtocol() : super('Querying WHO protocol…'); }
class StepGeneratingVerdict extends AnalysisStep { const StepGeneratingVerdict() : super('Generating triage decision…'); }
class StepComplete extends AnalysisStep { const StepComplete() : super('Done'); }
