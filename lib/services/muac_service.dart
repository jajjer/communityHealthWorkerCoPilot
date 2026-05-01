import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

class MuacReading {
  final double measurementCm;
  final String zone; // red | yellow | green
  final String status;

  const MuacReading({
    required this.measurementCm,
    required this.zone,
    required this.status,
  });

  // Maps to the condition the LLM should use for triage
  String get triageHint {
    switch (zone) {
      case 'red':
        return 'MUAC ${measurementCm.toStringAsFixed(1)}cm — Severe Acute Malnutrition (SAM). ';
      case 'yellow':
        return 'MUAC ${measurementCm.toStringAsFixed(1)}cm — Moderate Acute Malnutrition (MAM). ';
      default:
        return 'MUAC ${measurementCm.toStringAsFixed(1)}cm — Well nourished. ';
    }
  }
}

class MuacService {
  static const _channel = MethodChannel('com.chwcopilot.app/litert');

  Future<MuacReading?> analyzePhoto(XFile photo) async {
    final bytes = await photo.readAsBytes();
    final raw = await _channel.invokeMethod<String>(
      'analyzeImage',
      {'imageBytes': bytes, 'mimeType': 'image/jpeg'},
    );
    return raw != null ? _parse(raw) : null;
  }

  MuacReading? _parse(String raw) {
    final measurementMatch = RegExp(r'MEASUREMENT:\s*([\d.]+)').firstMatch(raw);
    final zoneMatch = RegExp(r'ZONE:\s*(\w+)', caseSensitive: false).firstMatch(raw);
    final statusMatch = RegExp(r'STATUS:\s*(.+)').firstMatch(raw);

    if (measurementMatch == null || zoneMatch == null) return null;

    final measurement = double.tryParse(measurementMatch.group(1) ?? '');
    if (measurement == null) return null;

    return MuacReading(
      measurementCm: measurement,
      zone: zoneMatch.group(1)?.toLowerCase() ?? 'green',
      status: statusMatch?.group(1)?.trim() ?? _zoneToStatus(zoneMatch.group(1) ?? ''),
    );
  }

  String _zoneToStatus(String zone) => switch (zone.toLowerCase()) {
        'red' => 'Severe Acute Malnutrition',
        'yellow' => 'Moderate Acute Malnutrition',
        _ => 'Well Nourished',
      };
}
