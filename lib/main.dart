import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'services/protocol_db.dart';
import 'screens/capture_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize protocol DB and pre-warm cache at startup (D8).
  // All 60 rows loaded into memory before any patient encounter.
  final db = await ProtocolDb.init();
  await db.ensureCaseLogTable();

  runApp(
    ProviderScope(
      overrides: [
        protocolDbProvider.overrideWithValue(db),
      ],
      child: const CopilotApp(),
    ),
  );
}

class CopilotApp extends StatelessWidget {
  const CopilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'chwCoPilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const CaptureScreen(),
    );
  }
}
