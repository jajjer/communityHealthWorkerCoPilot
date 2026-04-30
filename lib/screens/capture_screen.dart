import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'analyzing_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _textController = TextEditingController();
  bool _isRecording = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
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
                  const Text('▓▓▓ 87%',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('chwCoPilot',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const Text('Clinical Decision Support',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
              const SizedBox(height: 20),

              // Camera / photo area
              Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF333333), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Color(0xFF555555), size: 40),
                      const SizedBox(height: 8),
                      const Text('Tap to photograph MUAC tape',
                          style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
                      const SizedBox(height: 4),
                      const Text('(Day 7 — not yet integrated)',
                          style: TextStyle(color: Color(0xFF333333), fontSize: 9)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Voice / text input buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.camera_alt,
                      label: 'Photo',
                      sublabel: 'MUAC tape',
                      color: const Color(0xFF374151),
                      onTap: () => _showComingSoon(context, 'Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.mic,
                      label: 'Speak',
                      sublabel: 'Describe case',
                      color: const Color(0xFF7C3AED),
                      onTap: _onVoiceTap,
                      isActive: _isRecording,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Text input for Days 1-4 (before ASR integration)
              TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Or type symptoms (Days 1–4 text mode)…',
                  hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1F2937),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF374151)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF374151)),
                  ),
                ),
                onSubmitted: (_) => _onTextSubmit(context),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _onTextSubmit(context),
                  child: const Text('Triage →',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),

              const Spacer(),
              Row(
                children: [
                  const Text('Language: ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                  _LangBadge('Kiswahili ▾'),
                  const SizedBox(width: 6),
                  _LangBadge('+ EN'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onVoiceTap() {
    // Day 5-6: replace stub with AsrService.record() call
    setState(() => _isRecording = !_isRecording);
    if (_isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input coming Day 5-6 (ASR integration)')),
      );
    }
  }

  void _onTextSubmit(BuildContext context) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnalyzingScreen(input: text, isText: true)),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature integration: Day 7')),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.8) : color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(sublabel,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _LangBadge extends StatelessWidget {
  final String text;
  const _LangBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        border: Border.all(color: const Color(0xFF374151)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
    );
  }
}
