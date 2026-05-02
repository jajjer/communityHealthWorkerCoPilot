import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/muac_service.dart';
import 'analyzing_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _muacService = MuacService();
  final _speech = SpeechToText();

  CameraController? _camera;
  bool _cameraReady = false;
  bool _isAnalyzingPhoto = false;
  MuacReading? _muacReading;

  bool _speechAvailable = false;
  bool _isListening = false;
  String _listeningLocale = 'sw_KE';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initCamera();
    _initSpeech();
  }

  @override
  void dispose() {
    _camera?.dispose();
    _textController.dispose();
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final controller = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _camera = controller;
        _cameraReady = true;
      });
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    if (!mounted) return;

    if (available) {
      // Prefer Swahili if device has it, fall back to system locale
      final locales = await _speech.locales();
      final hasSwahili = locales.any((l) => l.localeId.startsWith('sw'));
      setState(() {
        _speechAvailable = true;
        _listeningLocale = hasSwahili ? 'sw_KE' : '';
      });
    }
  }

  Future<void> _onSpeakTap() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition unavailable on this device')),
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      localeId: _listeningLocale.isEmpty ? null : _listeningLocale,
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
          if (result.finalResult) _isListening = false;
        });
      },
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );
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
                  const Text('9:41', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('⊗ OFFLINE',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const Text('▓▓▓ 87%', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('chwCoPilot',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const Text('Clinical Decision Support',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
              const SizedBox(height: 20),

              // Camera preview / MUAC result area
              Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF333333), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.hardEdge,
                child: _buildCameraArea(),
              ),
              const SizedBox(height: 16),

              // MUAC result badge
              if (_muacReading != null) _MuacBadge(reading: _muacReading!),
              if (_muacReading != null) const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: _muacReading != null ? Icons.refresh : Icons.camera_alt,
                      label: _muacReading != null ? 'Retake' : 'Photo',
                      sublabel: 'MUAC tape',
                      color: const Color(0xFF374151),
                      onTap: _isAnalyzingPhoto ? null : _onPhotoTap,
                      isLoading: _isAnalyzingPhoto,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isListening
                        ? _ListeningButton(
                            pulseAnim: _pulseAnim,
                            onTap: _onSpeakTap,
                            locale: _listeningLocale,
                          )
                        : _ActionButton(
                            icon: Icons.mic,
                            label: 'Speak',
                            sublabel: _listeningLocale.startsWith('sw') ? 'Kiswahili / EN' : 'Describe case',
                            color: const Color(0xFF7C3AED),
                            onTap: _onSpeakTap,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _isListening ? 'Listening…' : 'Describe symptoms…',
                  hintStyle: TextStyle(
                    color: _isListening ? const Color(0xFF7C3AED) : const Color(0xFF4B5563),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: _isListening
                      ? const Color(0xFF1A1030)
                      : const Color(0xFF1F2937),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _isListening ? const Color(0xFF7C3AED) : const Color(0xFF374151),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _isListening ? const Color(0xFF7C3AED) : const Color(0xFF374151),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _isListening ? const Color(0xFF7C3AED) : const Color(0xFF6B7280),
                    ),
                  ),
                ),
                onSubmitted: (_) => _onSubmit(context),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _onSubmit(context),
                  child: const Text('Triage →',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),

              const Spacer(),
              Row(
                children: [
                  const Text('Language: ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                  _LangBadge(_listeningLocale.startsWith('sw') ? 'Kiswahili ▾' : 'System ▾'),
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

  Widget _buildCameraArea() {
    if (_isAnalyzingPhoto) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7C3AED), strokeWidth: 2),
            SizedBox(height: 10),
            Text('Reading MUAC tape…',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
          ],
        ),
      );
    }

    if (_cameraReady && _camera != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_camera!),
          Center(
            child: Container(
              width: 180,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Center(
              child: Text('Align MUAC tape in frame',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 9,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                  )),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, color: const Color(0xFF555555), size: 40),
          const SizedBox(height: 8),
          const Text('Tap Photo to photograph MUAC tape',
              style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _onPhotoTap() async {
    if (!_cameraReady || _camera == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera unavailable')),
      );
      return;
    }
    setState(() => _isAnalyzingPhoto = true);
    try {
      final photo = await _camera!.takePicture();
      final reading = await _muacService.analyzePhoto(photo);
      if (!mounted) return;
      setState(() {
        _muacReading = reading;
        _isAnalyzingPhoto = false;
      });
      if (reading != null && _textController.text.isEmpty) {
        _textController.text = reading.triageHint;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo analysis failed: $e')),
      );
    }
  }

  void _onSubmit(BuildContext context) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (_isListening) _speech.stop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnalyzingScreen(input: text, isText: true)),
    );
  }
}

// Pulsing "Listening" button shown while ASR is active
class _ListeningButton extends StatelessWidget {
  final Animation<double> pulseAnim;
  final VoidCallback onTap;
  final String locale;

  const _ListeningButton({
    required this.pulseAnim,
    required this.onTap,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, __) => Transform.scale(
          scale: pulseAnim.value,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(Icons.stop, color: Colors.white, size: 24),
                SizedBox(height: 4),
                Text('Listening…',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('tap to stop', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MuacBadge extends StatelessWidget {
  final MuacReading reading;
  const _MuacBadge({required this.reading});

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, textColor) = switch (reading.zone) {
      'red' => (const Color(0xFF1A0000), const Color(0xFFDC2626), const Color(0xFFF87171)),
      'yellow' => (const Color(0xFF1C1200), const Color(0xFFD97706), const Color(0xFFFBBF24)),
      _ => (const Color(0xFF052E16), const Color(0xFF16A34A), const Color(0xFF4ADE80)),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('◉', style: TextStyle(color: borderColor, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'MUAC ${reading.measurementCm.toStringAsFixed(1)} cm — ${reading.status}',
              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null ? color.withValues(alpha: 0.5) : color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            isLoading
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(sublabel, style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
