import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/triage_result.dart';
import '../providers.dart';
import 'triage_screen.dart';

class AnalyzingScreen extends ConsumerStatefulWidget {
  final String input;
  final bool isText;

  const AnalyzingScreen({super.key, required this.input, this.isText = false});

  @override
  ConsumerState<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends ConsumerState<AnalyzingScreen> {
  final List<_StepState> _steps = [
    _StepState('Audio transcribed', status: _Status.pending),
    _StepState('WHO protocol queried', status: _Status.pending),
    _StepState('Triage decision generated', status: _Status.pending),
  ];
  final List<String> _functionCallLog = [];
  int _activeStep = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final engine = ref.read(triageEngineProvider);

    Future<TriageResult> task;
    if (widget.isText) {
      task = engine.runText(
        widget.input,
        onStep: _handleStep,
      );
    } else {
      task = engine.run(
        widget.input,
        onStep: _handleStep,
      );
    }

    final result = await task;

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TriageScreen(result: result)),
      );
    }
  }

  void _handleStep(AnalysisStep step) {
    if (!mounted) return;
    setState(() {
      switch (step) {
        case StepTranscribing():
          _steps[0] = _StepState('Transcribing audio…', status: _Status.active);
          _activeStep = 0;
        case StepTranscribed(:final transcript):
          _steps[0] = _StepState('Transcribed: "$transcript"', status: _Status.done);
          _activeStep = 1;
        case StepQueryingProtocol():
          _steps[1] = _StepState('Querying WHO protocol…', status: _Status.active);
          _functionCallLog.add('→ query_protocol(\n  condition="...",\n  age_group="child",\n  severity="moderate"\n)');
        case StepGeneratingVerdict():
          _steps[1] = _StepState('Protocol retrieved', status: _Status.done);
          _steps[2] = _StepState('Generating triage decision…', status: _Status.active);
          _activeStep = 2;
        case StepComplete():
          _steps[2] = _StepState('Triage decision ready', status: _Status.done);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('9:41',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('⊗ OFFLINE',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 24),

              // Spinner + label
              Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Analyzing case…',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Step list
              ..._steps.map((s) => _StepRow(step: s)),
              const SizedBox(height: 16),

              // Function call log
              if (_functionCallLog.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    border: Border.all(color: const Color(0xFF333333)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FUNCTION CALL LOG',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 9, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      ..._functionCallLog.map((log) => Text(
                            log,
                            style: const TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 9,
                              fontFamily: 'monospace',
                              height: 1.6,
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Audit trail — every call logged',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 9, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _Status { pending, active, done }

class _StepState {
  final String label;
  final _Status status;
  const _StepState(this.label, {required this.status});
}

class _StepRow extends StatelessWidget {
  final _StepState step;
  const _StepRow({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    final color = switch (step.status) {
      _Status.done => const Color(0xFF10B981),
      _Status.active => const Color(0xFFE5E7EB),
      _Status.pending => const Color(0xFF444444),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(step.label,
                style: TextStyle(color: color, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
