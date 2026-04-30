import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chw_copilot/models/protocol.dart';
import 'package:chw_copilot/models/triage_result.dart';
import 'package:chw_copilot/screens/triage_screen.dart';

void main() {
  group('TriageScreen', () {
    testWidgets('renders error view with back button on TriageError', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TriageScreen(result: TriageError('Network timeout')),
        ),
      );
      expect(find.text('← Back'), findsOneWidget);
      expect(find.text('Network timeout'), findsOneWidget);
    });

    testWidgets('renders REFER TO CLINIC for TriageUnclearCondition', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TriageScreen(
            result: TriageUnclearCondition(
              transcript: 'child has fever',
              reason: 'Could not match condition after 3 attempts',
            ),
          ),
        ),
      );
      expect(find.text('REFER TO CLINIC'), findsOneWidget);
      expect(find.text('+ New Patient'), findsOneWidget);
    });

    testWidgets('renders TREAT LOCALLY verdict for treat_locally protocol', (tester) async {
      final protocol = Protocol(
        condition: Condition.malariaUncomplicated,
        ageGroup: AgeGroup.child,
        severity: Severity.mild,
        verdict: TriageVerdict.treatLocally,
        steps: ['Give artemether-lumefantrine', 'Paracetamol for fever'],
        source: 'WHO_IMCI',
      );
      final functionCall = FunctionCall(
        condition: Condition.malariaUncomplicated,
        ageGroup: AgeGroup.child,
        severity: Severity.mild,
        symptomFlags: ['fever'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TriageScreen(
            result: TriageSuccess(
              protocol: protocol,
              transcript: 'child has fever',
              functionCall: functionCall,
              conditionLabel: 'Uncomplicated Malaria',
              verdictText: 'Treat locally with artemether-lumefantrine.',
              timestamp: DateTime(2026, 4, 30, 9, 0),
            ),
          ),
        ),
      );
      expect(find.text('TREAT LOCALLY'), findsOneWidget);
      expect(find.text('Uncomplicated Malaria'), findsOneWidget);
    });

    testWidgets('renders EMERGENCY verdict for emergency protocol', (tester) async {
      final protocol = Protocol(
        condition: Condition.malariaSevere,
        ageGroup: AgeGroup.child,
        severity: Severity.severe,
        verdict: TriageVerdict.emergency,
        steps: ['Call ambulance immediately'],
        source: 'WHO_IMCI',
      );
      final functionCall = FunctionCall(
        condition: Condition.malariaSevere,
        ageGroup: AgeGroup.child,
        severity: Severity.severe,
        symptomFlags: ['convulsions'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TriageScreen(
            result: TriageSuccess(
              protocol: protocol,
              transcript: 'child convulsing',
              functionCall: functionCall,
              conditionLabel: 'Severe Malaria',
              verdictText: 'EMERGENCY — call ambulance immediately.',
              timestamp: DateTime(2026, 4, 30, 9, 0),
            ),
          ),
        ),
      );
      expect(find.text('EMERGENCY'), findsOneWidget);
    });
  });
}
