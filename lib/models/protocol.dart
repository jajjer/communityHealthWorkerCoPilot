import 'dart:convert';

// 20-value enum matching what Gemma 4 E2B is fine-tuned to output.
// ANY string from the LLM must be validated against this enum before SQLite lookup.
enum Condition {
  malariaUncomplicated('malaria_uncomplicated'),
  malariaSevere('malaria_severe'),
  pneumoniaMild('pneumonia_mild'),
  pneumoniaSevere('pneumonia_severe'),
  diarrheaMild('diarrhea_mild'),
  diarrheaSevere('diarrhea_severe'),
  severeAcuteMalnutrition('severe_acute_malnutrition'),
  moderateAcuteMalnutrition('moderate_acute_malnutrition'),
  measlesMild('measles_mild'),
  measlesComplicated('measles_complicated'),
  tuberculosisSuspicion('tuberculosis_suspicion'),
  hivAidsSymptomatic('hiv_aids_symptomatic'),
  neonatalSepsis('neonatal_sepsis'),
  neonatalJaundice('neonatal_jaundice'),
  feverWithoutSource('fever_without_source'),
  acuteRespiratoryInfection('acute_respiratory_infection'),
  skinInfection('skin_infection'),
  eyeInfection('eye_infection'),
  woundTrauma('wound_trauma'),
  pregnancyEmergency('pregnancy_emergency');

  const Condition(this.value);
  final String value;

  static Condition? fromString(String s) {
    for (final c in values) {
      if (c.value == s) return c;
    }
    return null;
  }
}

enum AgeGroup {
  neonate('neonate'),
  infant('infant'),
  child('child'),
  adult('adult');

  const AgeGroup(this.value);
  final String value;

  static AgeGroup? fromString(String s) {
    for (final a in values) {
      if (a.value == s) return a;
    }
    return null;
  }
}

enum Severity {
  mild('mild'),
  moderate('moderate'),
  severe('severe');

  const Severity(this.value);
  final String value;

  static Severity? fromString(String s) {
    for (final sv in values) {
      if (sv.value == s) return sv;
    }
    return null;
  }
}

enum TriageVerdict {
  treatLocally('treat_locally'),
  refer('refer'),
  emergency('emergency');

  const TriageVerdict(this.value);
  final String value;
}

class Protocol {
  final Condition condition;
  final AgeGroup ageGroup;
  final Severity severity;
  final TriageVerdict verdict;
  final List<String> steps;
  final String source; // "WHO_IMCI" | "MSF"

  const Protocol({
    required this.condition,
    required this.ageGroup,
    required this.severity,
    required this.verdict,
    required this.steps,
    required this.source,
  });

  String get cacheKey => '${condition.value}_${ageGroup.value}_${severity.value}';

  factory Protocol.fromMap(Map<String, dynamic> map) {
    final condition = Condition.fromString(map['condition'] as String);
    final ageGroup = AgeGroup.fromString(map['age_group'] as String);
    final severity = Severity.fromString(map['severity'] as String);
    final verdict = TriageVerdict.values.where((v) => v.value == map['triage_verdict']).firstOrNull;

    if (condition == null || ageGroup == null || severity == null || verdict == null) {
      throw FormatException(
        'Invalid protocol row: condition=${map["condition"]}, '
        'age_group=${map["age_group"]}, severity=${map["severity"]}, '
        'triage_verdict=${map["triage_verdict"]}',
      );
    }

    return Protocol(
      condition: condition,
      ageGroup: ageGroup,
      severity: severity,
      verdict: verdict,
      steps: List<String>.from(jsonDecode(map['steps_json'] as String)),
      source: map['source'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'condition': condition.value,
    'age_group': ageGroup.value,
    'severity': severity.value,
    'triage_verdict': verdict.value,
    'steps_json': jsonEncode(steps),
    'source': source,
  };
}

// Parsed output of Gemma 4's query_protocol function call
class FunctionCall {
  final Condition condition;
  final AgeGroup ageGroup;
  final Severity severity;
  final List<String> symptomFlags;

  const FunctionCall({
    required this.condition,
    required this.ageGroup,
    required this.severity,
    required this.symptomFlags,
  });

  static FunctionCall? fromJson(Map<String, dynamic> json) {
    final params = json['parameters'] as Map<String, dynamic>?;
    if (params == null) return null;

    final condition = Condition.fromString(params['condition'] as String? ?? '');
    final ageGroup = AgeGroup.fromString(params['age_group'] as String? ?? '');
    final severity = Severity.fromString(params['severity'] as String? ?? '');

    if (condition == null || ageGroup == null || severity == null) return null;

    return FunctionCall(
      condition: condition,
      ageGroup: ageGroup,
      severity: severity,
      symptomFlags: List<String>.from(params['symptom_flags'] as List? ?? []),
    );
  }
}
