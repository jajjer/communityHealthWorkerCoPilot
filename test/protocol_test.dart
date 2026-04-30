import 'package:flutter_test/flutter_test.dart';
import 'package:chw_copilot/models/protocol.dart';

void main() {
  group('Condition enum', () {
    test('fromString returns correct enum for all 20 conditions', () {
      final cases = [
        ('malaria_uncomplicated', Condition.malariaUncomplicated),
        ('malaria_severe', Condition.malariaSevere),
        ('pneumonia_mild', Condition.pneumoniaMild),
        ('pneumonia_severe', Condition.pneumoniaSevere),
        ('diarrhea_mild', Condition.diarrheaMild),
        ('diarrhea_severe', Condition.diarrheaSevere),
        ('severe_acute_malnutrition', Condition.severeAcuteMalnutrition),
        ('moderate_acute_malnutrition', Condition.moderateAcuteMalnutrition),
        ('measles_mild', Condition.measlesMild),
        ('measles_complicated', Condition.measlesComplicated),
        ('tuberculosis_suspicion', Condition.tuberculosisSuspicion),
        ('hiv_aids_symptomatic', Condition.hivAidsSymptomatic),
        ('neonatal_sepsis', Condition.neonatalSepsis),
        ('neonatal_jaundice', Condition.neonatalJaundice),
        ('fever_without_source', Condition.feverWithoutSource),
        ('acute_respiratory_infection', Condition.acuteRespiratoryInfection),
        ('skin_infection', Condition.skinInfection),
        ('eye_infection', Condition.eyeInfection),
        ('wound_trauma', Condition.woundTrauma),
        ('pregnancy_emergency', Condition.pregnancyEmergency),
      ];

      for (final (str, expected) in cases) {
        expect(Condition.fromString(str), equals(expected),
            reason: 'fromString("$str") should return $expected');
      }
    });

    test('fromString returns null for unknown strings (enum guard)', () {
      expect(Condition.fromString(''), isNull);
      expect(Condition.fromString('unknown_condition'), isNull);
      expect(Condition.fromString('malaria'), isNull); // partial match — must reject
      expect(Condition.fromString('MALARIA_UNCOMPLICATED'), isNull); // case-sensitive
    });

    test('all 20 conditions have non-empty value strings', () {
      for (final c in Condition.values) {
        expect(c.value, isNotEmpty, reason: '${c.name} has empty value');
        expect(c.value, isNot(contains(' ')), reason: '${c.name} value has spaces — SQLite key will break');
      }
    });
  });

  group('FunctionCall.fromJson', () {
    test('parses valid Gemma 4 output correctly', () {
      final json = {
        'function': 'query_protocol',
        'parameters': {
          'condition': 'measles_mild',
          'age_group': 'child',
          'severity': 'moderate',
          'symptom_flags': ['fever', 'rash'],
        },
      };

      final call = FunctionCall.fromJson(json);
      expect(call, isNotNull);
      expect(call!.condition, equals(Condition.measlesMild));
      expect(call.ageGroup, equals(AgeGroup.child));
      expect(call.severity, equals(Severity.moderate));
      expect(call.symptomFlags, equals(['fever', 'rash']));
    });

    test('returns null for unknown condition string (enum validation)', () {
      final json = {
        'function': 'query_protocol',
        'parameters': {
          'condition': 'covid_19', // not in the 20-condition enum
          'age_group': 'adult',
          'severity': 'mild',
          'symptom_flags': [],
        },
      };

      expect(FunctionCall.fromJson(json), isNull);
    });

    test('returns null when parameters key is missing', () {
      expect(FunctionCall.fromJson({'function': 'query_protocol'}), isNull);
    });

    test('SAM child severe maps to emergency verdict', () {
      final json = {
        'function': 'query_protocol',
        'parameters': {
          'condition': 'severe_acute_malnutrition',
          'age_group': 'child',
          'severity': 'severe',
          'symptom_flags': ['muac_red'],
        },
      };

      final call = FunctionCall.fromJson(json);
      expect(call, isNotNull);
      expect(call!.condition, equals(Condition.severeAcuteMalnutrition));
    });
  });

  group('Protocol.cacheKey', () {
    test('cache key format matches lookup key format', () {
      final protocol = Protocol(
        condition: Condition.measlesMild,
        ageGroup: AgeGroup.child,
        severity: Severity.moderate,
        verdict: TriageVerdict.treatLocally,
        steps: ['Step 1'],
        source: 'WHO_IMCI',
      );

      expect(protocol.cacheKey, equals('measles_mild_child_moderate'));
    });
  });
}
