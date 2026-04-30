import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/protocol.dart';

// All 60 protocol rows (20 conditions × 3 severity) cached at startup.
// Eliminates SQLite I/O from the latency-critical inference path.
class ProtocolDb {
  static ProtocolDb? _instance;
  static Database? _db;
  final Map<String, Protocol> _cache = {};

  ProtocolDb._();

  static Future<ProtocolDb> init() async {
    if (_instance != null) return _instance!;
    _instance = ProtocolDb._();
    await _instance!._open();
    return _instance!;
  }

  Future<void> _open() async {
    final dbPath = p.join(await getDatabasesPath(), 'protocols.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE protocols (
            id INTEGER PRIMARY KEY,
            condition TEXT NOT NULL,
            age_group TEXT NOT NULL,
            severity TEXT NOT NULL,
            triage_verdict TEXT NOT NULL,
            steps_json TEXT NOT NULL,
            source TEXT NOT NULL
          )
        ''');
        await _seed(db);
      },
    );
    await _loadCache();
  }

  Future<void> _seed(Database db) async {
    final raw = await rootBundle.loadString('assets/protocols.json');
    final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('protocols', row);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _loadCache() async {
    final rows = await _db!.query('protocols');
    for (final row in rows) {
      final p = Protocol.fromMap(row);
      _cache[p.cacheKey] = p;
    }
  }

  // O(1) lookup — never hits SQLite after startup
  Protocol? lookup(Condition condition, AgeGroup ageGroup, Severity severity) {
    return _cache['${condition.value}_${ageGroup.value}_${severity.value}'];
  }

  Future<void> logCase({
    required FunctionCall call,
    required TriageVerdict verdict,
    required String transcript,
    required DateTime timestamp,
    double? latitude,
    double? longitude,
  }) async {
    await _db!.insert('case_log', {
      'condition': call.condition.value,
      'age_group': call.ageGroup.value,
      'severity': call.severity.value,
      'symptom_flags': jsonEncode(call.symptomFlags),
      'verdict': verdict.value,
      'transcript': transcript,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'synced': 0,
    });
  }

  Future<void> ensureCaseLogTable() async {
    await _db!.execute('''
      CREATE TABLE IF NOT EXISTS case_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        condition TEXT NOT NULL,
        age_group TEXT NOT NULL,
        severity TEXT NOT NULL,
        symptom_flags TEXT,
        verdict TEXT NOT NULL,
        transcript TEXT,
        timestamp TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
