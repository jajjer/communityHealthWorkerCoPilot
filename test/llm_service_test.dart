import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:chw_copilot/services/llm_service.dart';
import 'package:chw_copilot/models/protocol.dart';

void main() {
  group('LlmService JSON parsing', () {
    test('parses clean JSON output', () {
      const raw = '{"function":"query_protocol","parameters":{"condition":"measles_mild","age_group":"child","severity":"moderate","symptom_flags":["fever","rash"]}}';
      final call = _parseFunctionCall(raw);
      expect(call, isNotNull);
      expect(call!.condition, equals(Condition.measlesMild));
      expect(call.ageGroup, equals(AgeGroup.child));
      expect(call.severity, equals(Severity.moderate));
    });

    test('parses JSON wrapped in markdown code fence', () {
      const raw = '```json\n{"function":"query_protocol","parameters":{"condition":"measles_mild","age_group":"child","severity":"mild","symptom_flags":[]}}\n```';
      expect(_parseFunctionCall(raw), isNotNull);
    });

    test('returns null for plain text (retry loop trigger)', () {
      expect(_parseFunctionCall('Sorry, I cannot determine the condition.'), isNull);
      expect(_parseFunctionCall(''), isNull);
    });

    test('returns null when condition is not in 20-value enum', () {
      const raw = '{"function":"query_protocol","parameters":{"condition":"covid_19","age_group":"adult","severity":"mild","symptom_flags":[]}}';
      expect(_parseFunctionCall(raw), isNull);
    });

    test('returns null when function name is wrong', () {
      const raw = '{"function":"wrong_function","parameters":{"condition":"measles_mild","age_group":"child","severity":"mild","symptom_flags":[]}}';
      expect(_parseFunctionCall(raw), isNull);
    });

    test('SAM severe maps to correct condition', () {
      const raw = '{"function":"query_protocol","parameters":{"condition":"severe_acute_malnutrition","age_group":"child","severity":"severe","symptom_flags":["muac_red"]}}';
      final call = _parseFunctionCall(raw);
      expect(call, isNotNull);
      expect(call!.condition, equals(Condition.severeAcuteMalnutrition));
    });

    test('function call prompt contains all 20 condition strings', () {
      final prompt = LlmService.functionCallPrompt('child has fever and rash');
      for (final c in Condition.values) {
        expect(prompt, contains(c.value),
            reason: 'Prompt is missing condition: ${c.value}');
      }
    });
  });
}

// Mirror of LlmService._parseFunctionCall — kept in sync manually.
// If you change the parsing logic in LlmService, update this too.
FunctionCall? _parseFunctionCall(String raw) {
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
