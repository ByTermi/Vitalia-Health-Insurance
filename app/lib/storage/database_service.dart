import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class SensorReading {
  final int? id;
  final int ts;
  final double ax, ay, az;
  final double gx, gy, gz;
  final double svm;
  final String? activity;

  const SensorReading({
    this.id,
    required this.ts,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.svm,
    this.activity,
  });

  Map<String, dynamic> toMap() => {
        'ts': ts,
        'ax': ax, 'ay': ay, 'az': az,
        'gx': gx, 'gy': gy, 'gz': gz,
        'svm': svm,
        'activity': activity,
      };

  factory SensorReading.fromMap(Map<String, dynamic> m) => SensorReading(
        id: m['id'] as int?,
        ts: m['ts'] as int,
        ax: (m['ax'] as num).toDouble(),
        ay: (m['ay'] as num).toDouble(),
        az: (m['az'] as num).toDouble(),
        gx: (m['gx'] as num).toDouble(),
        gy: (m['gy'] as num).toDouble(),
        gz: (m['gz'] as num).toDouble(),
        svm: (m['svm'] as num).toDouble(),
        activity: m['activity'] as String?,
      );
}

class ServerProfile {
  final int? id;
  final String name;
  final String ip;
  final int port;
  final int lastUsed;

  const ServerProfile({
    this.id,
    required this.name,
    required this.ip,
    this.port = 8000,
    required this.lastUsed,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'ip': ip,
        'port': port,
        'last_used': lastUsed,
      };

  factory ServerProfile.fromMap(Map<String, dynamic> m) => ServerProfile(
        id: m['id'] as int?,
        name: m['name'] as String,
        ip: m['ip'] as String,
        port: (m['port'] as int?) ?? 8000,
        lastUsed: m['last_used'] as int,
      );
}

class FallEvent {
  final int? id;
  final int ts;
  final int stage;
  final double svmPeak;
  final double cnnProb;
  final bool immobility;

  const FallEvent({
    this.id,
    required this.ts,
    required this.stage,
    required this.svmPeak,
    required this.cnnProb,
    required this.immobility,
  });

  Map<String, dynamic> toMap() => {
        'ts': ts,
        'stage': stage,
        'svm_peak': svmPeak,
        'cnn_prob': cnnProb,
        'immobility': immobility ? 1 : 0,
      };
}

class DatabaseService {
  static DatabaseService? _instance;
  Database? _db;

  DatabaseService._();
  static DatabaseService get instance => _instance ??= DatabaseService._();

  Future<void> init() async {
    final dbPath = p.join(await getDatabasesPath(), 'vitalia.db');
    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE sensor_readings (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            ts       INTEGER NOT NULL,
            ax REAL, ay REAL, az REAL,
            gx REAL, gy REAL, gz REAL,
            svm      REAL,
            activity TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE fall_events (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            ts        INTEGER NOT NULL,
            stage     INTEGER,
            svm_peak  REAL,
            cnn_prob  REAL,
            immobility INTEGER
          )
        ''');
        await db.execute('CREATE INDEX idx_ts ON sensor_readings(ts)');
        await _createProfilesTable(db);
        await _createSettingsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createProfilesTable(db);
        if (oldVersion < 3) await _createSettingsTable(db);
      },
    );
  }

  static Future<void> _createSettingsTable(Database db) async {
    await db.execute(
        'CREATE TABLE settings (key TEXT PRIMARY KEY, value REAL)');
  }

  // Threshold settings — key→value (e.g. cnn_balanced, svm_threshold, stairs_alt).
  Future<double?> getSetting(String key) async {
    final rows = await _db?.query('settings',
            where: 'key = ?', whereArgs: [key], limit: 1) ??
        [];
    if (rows.isEmpty) return null;
    return (rows.first['value'] as num?)?.toDouble();
  }

  Future<void> setSetting(String key, double value) async {
    await _db?.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, double>> getAllSettings() async {
    final rows = await _db?.query('settings') ?? [];
    return {
      for (final r in rows) r['key'] as String: (r['value'] as num).toDouble(),
    };
  }

  static Future<void> _createProfilesTable(Database db) async {
    await db.execute('''
      CREATE TABLE server_profiles (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        name      TEXT NOT NULL,
        ip        TEXT NOT NULL,
        port      INTEGER NOT NULL DEFAULT 8000,
        last_used INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertProfile(ServerProfile p) async {
    return await _db!.insert('server_profiles', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProfile(int id) async {
    await _db?.delete('server_profiles', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> touchProfile(int id) async {
    await _db?.update(
      'server_profiles',
      {'last_used': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ServerProfile>> getAllProfiles() async {
    final rows = await _db?.query('server_profiles', orderBy: 'last_used DESC') ?? [];
    return rows.map(ServerProfile.fromMap).toList();
  }

  Future<ServerProfile?> getLastUsedProfile() async {
    final rows = await _db?.query('server_profiles',
        orderBy: 'last_used DESC', limit: 1) ?? [];
    if (rows.isEmpty) return null;
    return ServerProfile.fromMap(rows.first);
  }

  Future<void> insertReading(SensorReading r) async {
    await _db?.insert('sensor_readings', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertFallEvent(FallEvent e) async {
    await _db?.insert('fall_events', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Last [limit] readings ordered by ts DESC.
  Future<List<SensorReading>> recentReadings({int limit = 500}) async {
    final rows = await _db?.query(
          'sensor_readings',
          orderBy: 'ts DESC',
          limit: limit,
        ) ??
        [];
    return rows.map(SensorReading.fromMap).toList().reversed.toList();
  }

  Future<List<Map<String, dynamic>>> recentFalls({int limit = 20}) async {
    return await _db?.query('fall_events', orderBy: 'ts DESC', limit: limit) ?? [];
  }

  Future<int> readingCount() async {
    final r = await _db?.rawQuery('SELECT COUNT(*) as c FROM sensor_readings');
    return (r?.first['c'] as int?) ?? 0;
  }

  /// Delete readings older than [keepMs] milliseconds from now.
  Future<void> pruneOld({int keepMs = 3600000}) async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - keepMs;
    await _db?.delete('sensor_readings', where: 'ts < ?', whereArgs: [cutoff]);
  }

  Future<void> close() async => await _db?.close();
}
