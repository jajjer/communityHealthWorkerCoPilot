import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/muac_service.dart';
import 'analyzing_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _textController = TextEditingController();
  final _muacService = MuacService();

  CameraController? _camera;
  bool _cameraReady = false;
  bool _isAnalyzingPhoto = false;
  MuacReading? _muacReading;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _camera?.dispose();
    _textController.dispose();
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
    } catch (_) {
      // Camera unavailable — text-only mode
    }
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
                    child: _ActionButton(
                      icon: Icons.mic,
                      label: 'Speak',
                      sublabel: 'Describe case',
                      color: const Color(0xFF7C3AED),
                      onTap: () => _showComingSoon(context, 'Voice input'),
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
                  hintText: 'Describe symptoms…',
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
          // Viewfinder overlay
          Center(
            child: Container(
              width: 180,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
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
                    color: Colors.white.withOpacity(0.7),
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
          Icon(Icons.camera_alt_outlined,
              color: const Color(0xFF555555), size: 40),
          const SizedBox(height: 8),
          const Text('Tap Photo to photograph MUAC tape',
              style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _onPhotoTap() async {
    if (!_cameraReady || _camera == null) {
      _showComingSoon(context, 'Camera');
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnalyzingScreen(input: text, isText: true)),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon')),
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
          color: onTap == null ? color.withOpacity(0.5) : color,
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
