import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/asr_service.dart';
import 'services/llm_service.dart';
import 'services/protocol_db.dart';
import 'services/triage_engine.dart';

final protocolDbProvider = Provider<ProtocolDb>((ref) {
  throw UnimplementedError('Override in ProviderScope with initialized ProtocolDb');
});

final llmServiceProvider = Provider<LlmService>((ref) => LlmService());

final asrServiceProvider = Provider<AsrService>((ref) => AsrService());

final triageEngineProvider = Provider<TriageEngine>((ref) {
  return TriageEngine(
    db: ref.watch(protocolDbProvider),
    llm: ref.watch(llmServiceProvider),
    asr: ref.watch(asrServiceProvider),
  );
});
