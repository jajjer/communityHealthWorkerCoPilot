import 'package:flutter/material.dart';
import '../models/protocol.dart';
import '../models/triage_result.dart';
import 'capture_screen.dart';

class TriageScreen extends StatelessWidget {
  final TriageResult result;

  const TriageScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: switch (result) {
          TriageSuccess() => _SuccessView(result: result as TriageSuccess),
          TriageUnclearCondition() => _UnclearView(result: result as TriageUnclearCondition),
          TriageError() => _ErrorView(result: result as TriageError),
        },
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final TriageSuccess result;
  const _SuccessView({required this.result});

  @override
  Widget build(BuildContext context) {
    final verdict = result.protocol.verdict;
    final (bgColor, borderColor, iconStr, verdictLabel, textColor) = switch (verdict) {
      TriageVerdict.treatLocally => (
        const Color(0xFF052E16),
        const Color(0xFF16A34A),
        '✓',
        'TREAT LOCALLY',
        const Color(0xFF4ADE80),
      ),
      TriageVerdict.refer => (
        const Color(0xFF1C1200),
        const Color(0xFFD97706),
        '→',
        'REFER TO CLINIC',
        const Color(0xFFFBBF24),
      ),
      TriageVerdict.emergency => (
        const Color(0xFF1A0000),
        const Color(0xFFDC2626),
        '⚠',
        'EMERGENCY',
        const Color(0xFFF87171),
      ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Triage card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(iconStr, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 6),
                Text(verdictLabel,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 4),
                Text(result.conditionLabel,
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // LLM verdict text
          if (result.verdictText.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                result.verdictText,
                style: TextStyle(color: textColor, fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Protocol steps
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.protocol.source} Protocol — ${result.conditionLabel}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                ...result.protocol.steps.asMap().entries.map(
                  (e) => _ProtocolStep(num: e.key + 1, text: e.value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Audit trail row
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _auditText(result),
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Function call (audit trail detail)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('View function call log',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: const Color(0xFF0D1117),
                child: Text(
                  _functionCallText(result.functionCall),
                  style: const TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 9,
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // New Patient button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const CaptureScreen()),
                (_) => false,
              ),
              child: const Text('+ New Patient',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  String _auditText(TriageSuccess r) {
    final ts = '${r.timestamp.year}-${r.timestamp.month.toString().padLeft(2, '0')}-${r.timestamp.day.toString().padLeft(2, '0')} '
        '${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}';
    if (r.latitude != null && r.longitude != null) {
      return 'Case logged · $ts · GPS: ${r.latitude!.toStringAsFixed(1)}°, ${r.longitude!.toStringAsFixed(1)}°';
    }
    return 'Case logged · $ts · GPS unavailable';
  }

  String _functionCallText(FunctionCall call) =>
      '→ query_protocol(\n'
      '  condition="${call.condition.value}",\n'
      '  age_group="${call.ageGroup.value}",\n'
      '  severity="${call.severity.value}",\n'
      '  symptom_flags=${call.symptomFlags}\n'
      ')';
}

class _ProtocolStep extends StatelessWidget {
  final int num;
  final String text;
  const _ProtocolStep({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF374151),
              shape: BoxShape.circle,
            ),
            child: Text('$num',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _UnclearView extends StatelessWidget {
  final TriageUnclearCondition result;
  const _UnclearView({required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1200),
              border: Border.all(color: const Color(0xFFD97706), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('?', style: TextStyle(fontSize: 32, color: Color(0xFFFBBF24))),
                const SizedBox(height: 6),
                const Text('REFER TO CLINIC',
                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(result.reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Could not identify a matching condition. Refer to clinic as a precaution.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const CaptureScreen()),
                (_) => false,
              ),
              child: const Text('+ New Patient', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final TriageError result;
  const _ErrorView({required this.result});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 48),
            const SizedBox(height: 12),
            Text(result.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const CaptureScreen()),
                (_) => false,
              ),
              child: const Text('← Back', style: TextStyle(color: Color(0xFF7C3AED))),
            ),
          ],
        ),
      ),
    );
  }
}
