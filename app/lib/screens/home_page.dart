import 'dart:async';
import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../sensors/sensor_service.dart';
import '../inference/har_classifier.dart';
import '../inference/fall_detector.dart';
import '../storage/database_service.dart';
import '../services/api_service.dart';
import '../services/model_update_service.dart';
import '../services/ntfy_service.dart';
import 'settings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ── Models & sensors ──────────────────────────────────────────────
  final _sensorService = SensorService();
  final _harBuffer = SlidingWindowBuffer(
      windowSize: 128, overlap: 0.5, rowMapper: (s) => s.toListLinear());
  final _fallBuffer = SlidingWindowBuffer(windowSize: 100, overlap: 0.5);
  final _harClassifier = HarClassifier();
  final _fallDetector = FallDetector(mode: DetectionMode.balanced);

  StreamSubscription? _sensorSub;
  Timer? _pointsTimer;

  // ── UI state ──────────────────────────────────────────────────────
  HarResult? _lastHar;
  FallResult? _lastFall;
  double _svmG = 0.0;
  double _vitaPoints = 0;
  int _streakDays = 0;
  String _level = 'bronze';
  int _activeMinutes = 0;
  final Map<Activity, int> _activityMinutes = {};
  bool _modelsLoaded = false;
  bool _inFallAlert = false;
  SensorSample? _lastSample;
  int _tab = 0;

  // ── Backend ───────────────────────────────────────────────────────
  final _api = ApiService.instance;
  final _ntfy = NtfyService();
  StreamSubscription? _ntfySub;
  bool _backendConnected = false;
  String? _pendingFallId;

  // ── Tests tab ────────────────────────────────────────────────────
  final List<_TestResult> _testResults = [];
  bool _testRunning = false;
  bool _cancelRequested = false;

  // ── Chart & DB ────────────────────────────────────────────────────
  static const int _chartLen = 250; // 5 s @ 50 Hz
  static const int _dbDecimate = 10; // store 1 of every 10 samples → 5 Hz
  final List<double> _axBuf = [], _ayBuf = [], _azBuf = [];
  int _sampleCount = 0;
  int _dbReadingCount = 0;
  final _db = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _db.init();
    final lastProfile = await _db.getLastUsedProfile();
    if (lastProfile != null) {
      _api.ip = lastProfile.ip;
      _api.port = lastProfile.port;
    }

    // OTA: check for newer models before loading
    final ota = await ModelUpdateService.checkAndUpdate(_api);
    await _harClassifier.load(overridePath: ota.harPath);
    await _fallDetector.load(overridePath: ota.fallPath);

    final count = await _db.readingCount();
    final connected = await _api.checkHealth();

    // Load persisted VitaPoints from backend
    if (connected) {
      final vp = await _api.getVitaPoints();
      if (vp != null && mounted) {
        setState(() {
          _vitaPoints = vp.total;
          _streakDays = vp.streakDays;
          _level = vp.level;
        });
      }
    }

    setState(() {
      _modelsLoaded = true;
      _dbReadingCount = count;
      _backendConnected = connected;
    });
    _startSensors();
    _subscribeNtfy();
  }

  void _subscribeNtfy() {
    _ntfySub?.cancel();
    _ntfy.subscribe(_api.ip);
    _ntfySub = _ntfy.messages.listen(_onNtfyMessage);
  }

  void _onNtfyMessage(NtfyMessage msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 10),
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.title.isNotEmpty ? msg.title : 'Alerta de caída',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    msg.message,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startSensors() {
    _sensorService.start();
    _sensorSub = _sensorService.sampleStream.listen(_onSample);

    _pointsTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final activity = _lastHar?.activity;
      if (activity != null && activity.isActive) {
        setState(() {
          // Optimistic local increment — overwritten by backend response when online
          _vitaPoints += activity.vitaPointsPerMin;
          _activeMinutes++;
          _activityMinutes[activity] = (_activityMinutes[activity] ?? 0) + 1;
        });
        // Send activity event to backend — use response as source of truth
        _api.postActivity(
          activity: activity.name,
          durationSeconds: 60,
        ).then((res) {
          if (res != null && mounted) {
            setState(() {
              _backendConnected = true;
              _vitaPoints = (res['total_vitapoints'] as num).toDouble();
              _streakDays = res['streak_days'] as int;
              _level = res['level'] as String;
            });
          }
        });
      }
    });
  }

  void _onSample(SensorSample sample) {
    _sampleCount++;

    // Rolling chart buffer
    _axBuf.add(sample.ax);
    _ayBuf.add(sample.ay);
    _azBuf.add(sample.az);
    if (_axBuf.length > _chartLen) {
      _axBuf.removeAt(0);
      _ayBuf.removeAt(0);
      _azBuf.removeAt(0);
    }

    // SQLite — store every _dbDecimate-th sample
    if (_sampleCount % _dbDecimate == 0) {
      _db.insertReading(SensorReading(
        ts: DateTime.now().millisecondsSinceEpoch,
        ax: sample.ax, ay: sample.ay, az: sample.az,
        gx: sample.gx, gy: sample.gy, gz: sample.gz,
        svm: sample.svmG,
        activity: _lastHar?.activity.displayName,
      )).then((_) async {
        final c = await _db.readingCount();
        if (mounted) setState(() => _dbReadingCount = c);
      });
    }

    setState(() => _lastSample = sample);
    // HAR inference
    final harWindow = _harBuffer.addSample(sample);
    if (harWindow != null && _harClassifier.isLoaded) {
      final result = _harClassifier.classify(harWindow);
      if (result != null) setState(() => _lastHar = result);
    }

    // Fall detection (3-stage cascade)
    final fallWindow = _fallBuffer.addSample(sample);
    if (fallWindow != null) {
      final result = _fallDetector.analyze(fallWindow);
      setState(() {
        _lastFall = result;
        _svmG = result.svmPeak;
      });
      if (result.isFall && result.triggeredStage >= 2 && !_inFallAlert) {
        _db.insertFallEvent(FallEvent(
          ts: DateTime.now().millisecondsSinceEpoch,
          stage: result.triggeredStage,
          svmPeak: result.svmPeak,
          cnnProb: result.cnnProbability,
          immobility: result.immobilityConfirmed,
        ));
        // Send fall event to backend, store fall_id for ACK
        _api.postFall(
          stage: result.triggeredStage,
          svmPeak: result.svmPeak,
        ).then((fallId) {
          if (mounted) setState(() => _pendingFallId = fallId);
        });
        _triggerFallAlert(result);
      }
    }
  }

  void _triggerFallAlert(FallResult result) {
    setState(() => _inFallAlert = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFC0392B),
        title: const Text('¿Estás bien?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se ha detectado una posible caída.',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 8),
            _infoRow('Pico SVM', '${result.svmPeak.toStringAsFixed(2)} g'),
            _infoRow('Prob. CNN', '${(result.cnnProbability * 100).toStringAsFixed(0)}%'),
            _infoRow('Etapa', result.triggeredStage.toString()),
            const SizedBox(height: 12),
            const Text(
              'Si no respondes en 30 s, se alertará a tu contacto de emergencia.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _inFallAlert = false);
              // ACK cancels backend alert
              if (_pendingFallId != null) {
                _api.ackFall(_pendingFallId!);
                _pendingFallId = null;
              }
            },
            child: const Text('Estoy bien'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: const Color(0xFFC0392B)),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _inFallAlert = false);
              // No ACK → backend worker will send ntfy+email alert
            },
            child: const Text('Llamar a emergencias'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );

  @override
  void dispose() {
    _sensorSub?.cancel();
    _sensorService.dispose();
    _harClassifier.dispose();
    _fallDetector.dispose();
    _pointsTimer?.cancel();
    _ntfySub?.cancel();
    _ntfy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F35),
        title: const Text('Vitalia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (!_modelsLoaded)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              _backendConnected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: _backendConnected ? Colors.greenAccent : Colors.white38,
              size: 20,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white54),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _tab == 0
          ? _buildActivityTab()
          : _tab == 1
              ? _buildMetricsTab()
              : _buildTestsTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        backgroundColor: const Color(0xFF0D1F35),
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: 'Actividad'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Métricas'),
          BottomNavigationBarItem(icon: Icon(Icons.science_outlined), label: 'Pruebas'),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // TAB 1 — ACTIVIDAD
  // ────────────────────────────────────────────────────────────────

  Widget _buildActivityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _activityCard(),
          const SizedBox(height: 14),
          _vitaPointsCard(),
          const SizedBox(height: 14),
          _fallStatusCard(),
          const SizedBox(height: 14),
          _modeSelector(),
          const SizedBox(height: 14),
          _sensorReadingsCard(),
        ],
      ),
    );
  }

  Widget _activityCard() {
    final activity = _lastHar?.activity;
    final icons = {
      Activity.walking: Icons.directions_walk,
      Activity.upstairs: Icons.north,
      Activity.downstairs: Icons.south,
      Activity.sitting: Icons.chair_outlined,
      Activity.standing: Icons.accessibility_new,
      Activity.running: Icons.directions_run,
    };

    return _card(
      child: Column(
        children: [
          Icon(
            activity != null ? (icons[activity] ?? Icons.device_unknown) : Icons.sensors,
            size: 72,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 10),
          Text(
            !_modelsLoaded
                ? 'Cargando modelo…'
                : (activity?.displayName ?? 'Detectando…'),
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          if (_lastHar != null) ...[
            const SizedBox(height: 6),
            Text(
              'Confianza: ${(_lastHar!.confidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${activity?.vitaPointsPerMin ?? 0} VitaPoints/min',
              style: TextStyle(
                  color: (activity?.vitaPointsPerMin ?? 0) > 0
                      ? Colors.amber
                      : Colors.white38,
                  fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vitaPointsCard() {
    final levelColor = _level == 'gold'
        ? Colors.amber
        : _level == 'silver'
            ? Colors.blueGrey.shade300
            : Colors.brown.shade300;
    return _card(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('VitaPoints', _vitaPoints.toStringAsFixed(1), Icons.star_rounded, Colors.amber),
              Container(width: 1, height: 50, color: Colors.white12),
              _stat('Racha', '${_streakDays}d', Icons.local_fire_department, Colors.orangeAccent),
              Container(width: 1, height: 50, color: Colors.white12),
              _stat('Min activos', '$_activeMinutes', Icons.timer_outlined, Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: levelColor.withOpacity(0.5)),
                ),
                child: Text(
                  _level.toUpperCase(),
                  style: TextStyle(
                      color: levelColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _backendConnected ? 'sincronizado' : 'local',
                style: TextStyle(
                    color: _backendConnected ? Colors.greenAccent : Colors.white38,
                    fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _fallStatusCard() {
    final stage1Active = _svmG > FallDetector.svmThreshold;
    final color = _inFallAlert
        ? Colors.red.shade700
        : (stage1Active ? Colors.orange.shade800 : const Color(0xFF1A2D4A));

    return _card(
      color: color,
      child: Row(
        children: [
          Icon(
            _inFallAlert
                ? Icons.warning_amber_rounded
                : (stage1Active ? Icons.sensors : Icons.shield_outlined),
            color: _inFallAlert ? Colors.amber : (stage1Active ? Colors.orange : Colors.greenAccent),
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _inFallAlert
                      ? '¡Caída detectada!'
                      : (stage1Active ? 'Impacto — analizando CNN…' : 'Monitor activo'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'SVM: ${_svmG.toStringAsFixed(2)} g  |  '
                  'Umbral: ${FallDetector.svmThreshold.toStringAsFixed(1)} g  |  '
                  'Modo: ${_fallDetector.mode.name}',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSelector() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Modo detección caídas',
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
          const SizedBox(height: 10),
          SegmentedButton<DetectionMode>(
            style: SegmentedButton.styleFrom(
              backgroundColor: const Color(0xFF0A1628),
              selectedBackgroundColor: Colors.greenAccent.withOpacity(0.2),
              foregroundColor: Colors.white38,
              selectedForegroundColor: Colors.greenAccent,
            ),
            segments: const [
              ButtonSegment(value: DetectionMode.conservative, label: Text('65+', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: DetectionMode.balanced, label: Text('Estándar', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: DetectionMode.strict, label: Text('Estricto', style: TextStyle(fontSize: 12))),
            ],
            selected: {_fallDetector.mode},
            onSelectionChanged: (s) => setState(() => _fallDetector.mode = s.first),
          ),
        ],
      ),
    );
  }

  Widget _sensorReadingsCard() {
    final s = _lastSample;
    String fmt(double v) => v.toStringAsFixed(3);

    List<FlSpot> toSpots(List<double> buf) {
      return List.generate(buf.length, (i) => FlSpot(i.toDouble(), buf[i]));
    }

    final hasData = _axBuf.length > 2;

    return _card(
      color: const Color(0xFF0D1F35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────
          Row(
            children: [
              Text('Acelerómetro — últimos 5 s',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
              const Spacer(),
              _legend('X', Colors.redAccent),
              const SizedBox(width: 8),
              _legend('Y', Colors.greenAccent),
              const SizedBox(width: 8),
              _legend('Z', Colors.lightBlueAccent),
            ],
          ),
          const SizedBox(height: 10),

          // ── Line chart ──────────────────────────────────────────
          SizedBox(
            height: 120,
            child: hasData
                ? LineChart(
                    LineChartData(
                      minY: -3,
                      maxY: 3,
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.white10, strokeWidth: 0.5),
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (v, _) => Text(
                              v.toInt().toString(),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 9),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        _chartLine(toSpots(_axBuf), Colors.redAccent),
                        _chartLine(toSpots(_ayBuf), Colors.greenAccent),
                        _chartLine(toSpots(_azBuf), Colors.lightBlueAccent),
                      ],
                    ),
                    duration: Duration.zero,
                  )
                : const Center(
                    child: Text('Esperando datos…',
                        style: TextStyle(color: Colors.white24))),
          ),
          const SizedBox(height: 12),

          // ── Numeric values ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACELERÓMETRO (g)',
                        style: TextStyle(
                            color: Colors.greenAccent.withValues(alpha: 0.6),
                            fontSize: 10,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 3),
                    _sensorRow('X', s != null ? fmt(s.ax) : '—', Colors.redAccent),
                    _sensorRow('Y', s != null ? fmt(s.ay) : '—', Colors.greenAccent),
                    _sensorRow('Z', s != null ? fmt(s.az) : '—', Colors.lightBlueAccent),
                  ],
                ),
              ),
              Container(width: 1, height: 65, color: Colors.white10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GIROSCOPIO (rad/s)',
                          style: TextStyle(
                              color: Colors.amber.withValues(alpha: 0.6),
                              fontSize: 10,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      _sensorRow('X', s != null ? fmt(s.gx) : '—', Colors.redAccent),
                      _sensorRow('Y', s != null ? fmt(s.gy) : '—', Colors.greenAccent),
                      _sensorRow('Z', s != null ? fmt(s.gz) : '—', Colors.lightBlueAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('SVM: ',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
              Text(s != null ? '${s.svmG.toStringAsFixed(3)} g' : '—',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$_dbReadingCount lecturas en DB',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _chartLine(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        isCurved: false,
        color: color,
        barWidth: 1.2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );

  Widget _legend(String label, Color color) => Row(
        children: [
          Container(width: 12, height: 2, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _sensorRow(String axis, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
                width: 16,
                child: Text(axis,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 13))),
            const SizedBox(width: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontFamily: 'monospace')),
          ],
        ),
      );

  // ────────────────────────────────────────────────────────────────
  // TAB 2 — MÉTRICAS
  // ────────────────────────────────────────────────────────────────

  Widget _buildMetricsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Modelo HAR — Reconocimiento de Actividad'),
          _harModelCard(),
          const SizedBox(height: 14),
          _sectionTitle('VitaPoints por Actividad'),
          _vitaPointsBreakdownCard(),
          const SizedBox(height: 14),
          _sectionTitle('Detector de Caídas — Cascada 3 Etapas'),
          _fallModelCard(),
          const SizedBox(height: 14),
          _sectionTitle('Modos de Detección'),
          _modesExplanationCard(),
          const SizedBox(height: 14),
          _sectionTitle('Sesión — Actividad desglosada'),
          _sessionBreakdownCard(),
          const SizedBox(height: 14),
          _sectionTitle('Estado en tiempo real'),
          _realtimeDebugCard(),
        ],
      ),
    );
  }

  Widget _harModelCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricRow('Tipo', 'CNN 1D — 6 clases de actividad'),
          _metricRow('Entrada', '128 muestras × 6 canales @50 Hz (2.56 s)'),
          _metricRow('Canales', 'ax, ay, az (g) + gx, gy, gz (rad/s)'),
          _metricRow('Baseline RF', 'Recall 0.931 | AUC 0.986 (LOSO)'),
          _metricRow('Modelo', _harClassifier.isLoaded ? 'Cargado ✓' : 'No disponible'),
          _metricRow('Tamaño', 'har_model_int8.tflite (<500 KB)'),
          const SizedBox(height: 8),
          Text(
            'El modelo CNN clasifica cada ventana de 2.56 s de señal bruta del '
            'acelerómetro y giroscopio directamente, sin calcular features manuales. '
            'La cuantización INT8 lo hace ejecutable en 20–30 ms en cualquier smartphone.',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _vitaPointsBreakdownCard() {
    const activities = Activity.values;
    return _card(
      child: Column(
        children: activities.map((a) {
          final pts = a.vitaPointsPerMin;
          final color = pts >= 4
              ? Colors.greenAccent
              : pts >= 2
                  ? Colors.lightGreenAccent
                  : Colors.white24;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(a.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: pts / 5.0,
                    backgroundColor: Colors.white12,
                    color: color,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$pts pts/min',
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _fallModelCard() {
    final stages = [
      _FallStageInfo(
        stage: '1',
        name: 'Umbral SVM (always-on)',
        desc: 'Comprueba si el pico del vector de magnitud de aceleración supera '
            '${FallDetector.svmThreshold.toStringAsFixed(1)} g. '
            'Coste energético mínimo (<1 mW extra). Si se supera, activa la etapa 2.',
        active: _svmG > FallDetector.svmThreshold,
        value: 'SVM: ${_svmG.toStringAsFixed(2)} g',
      ),
      _FallStageInfo(
        stage: '2',
        name: 'CNN Confirmer (on-demand)',
        desc: 'Red CNN binaria sobre la ventana de 2 s centrada en el impacto. '
            'Solo se ejecuta si la etapa 1 se activa. '
            'Threshold configurable según segmento (65+: 0.30, estándar: 0.50, estricto: 0.70).',
        active: _lastFall != null && _lastFall!.cnnProbability > _fallDetector.threshold,
        value: _lastFall != null
            ? 'Prob: ${(_lastFall!.cnnProbability * 100).toStringAsFixed(1)}%'
            : 'Inactiva',
      ),
      _FallStageInfo(
        stage: '3',
        name: 'Inmovilidad post-caída',
        desc: 'Si el usuario no se mueve en los 0.5 s posteriores al impacto '
            '(varianza aceleración < 0.1 g²), se confirma la caída con alta certeza '
            'y se muestra el prompt "¿Estás bien?".',
        active: _lastFall?.immobilityConfirmed ?? false,
        value: _lastFall?.immobilityConfirmed == true ? 'Detectada' : 'No activa',
      ),
    ];

    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metricRow('Arquitectura', 'CNN 1D binario (fall / no-fall)'),
              _metricRow('Recall (modo conservador)', '~100%  (threshold 0.30)'),
              _metricRow('Recall (equilibrado)', '99.7%  (threshold 0.50)'),
              _metricRow('Precisión (estricto)', '>90%  (threshold 0.70)'),
              _metricRow('Tamaño', '${FallDetector.windowSize} muestras → 21.6 KB INT8'),
              _metricRow('Modelo', _fallDetector.isLoaded ? 'Cargado ✓' : 'No disponible'),
              const SizedBox(height: 8),
              Text(
                'Por qué como sub-problema binario: las caídas son eventos transitorios con '
                'señal muy diferente al resto. Entrenar un clasificador dedicado permite '
                'optimizar el recall de forma independiente y usar ventanas centradas en el '
                'impacto en lugar de ventanas deslizantes.',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...stages.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _card(
                color: s.active ? const Color(0xFF1B3A2A) : const Color(0xFF1A2D4A),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.active ? Colors.greenAccent : Colors.white12,
                      ),
                      child: Text(s.stage,
                          style: TextStyle(
                              color: s.active ? Colors.black : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(s.name,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              Text(s.value,
                                  style: TextStyle(
                                      color: s.active ? Colors.greenAccent : Colors.white38,
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(s.desc,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _modesExplanationCard() {
    final modes = [
      (
        mode: DetectionMode.conservative,
        label: 'Conservador (65+)',
        threshold: '0.30',
        recall: '~100%',
        precision: '~50%',
        desc: 'Prioriza no perderse ninguna caída. Acepta más falsas alarmas. '
            'Para asegurados mayores de 65 años donde el FN (caída no detectada) '
            'puede ser fatal.',
        color: Colors.orange,
      ),
      (
        mode: DetectionMode.balanced,
        label: 'Equilibrado',
        threshold: '0.50',
        recall: '99.7%',
        precision: '98.7%',
        desc: 'Maximiza el F1-score. Balance óptimo entre recall y precisión. '
            'Recomendado para la mayoría de asegurados (45–64 años).',
        color: Colors.greenAccent,
      ),
      (
        mode: DetectionMode.strict,
        label: 'Estricto',
        threshold: '0.70',
        recall: '~90%',
        precision: '>95%',
        desc: 'Minimiza las falsas alarmas. Para usuarios activos donde los FP '
            'generan desconfianza en el sistema y riesgo de desinstalación.',
        color: Colors.lightBlueAccent,
      ),
    ];

    return Column(
      children: modes.map((m) {
        final isActive = _fallDetector.mode == m.mode;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _card(
            color: isActive ? const Color(0xFF0D2D1A) : const Color(0xFF1A2D4A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: m.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: m.color.withOpacity(0.4)),
                      ),
                      child: Text(m.label,
                          style: TextStyle(
                              color: m.color, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('ACTIVO',
                            style: TextStyle(
                                color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const Spacer(),
                    Text('thr=${m.threshold}',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _badgeMetric('Recall', m.recall, Colors.redAccent),
                    const SizedBox(width: 8),
                    _badgeMetric('Precision', m.precision, Colors.blueAccent),
                  ],
                ),
                const SizedBox(height: 6),
                Text(m.desc,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sessionBreakdownCard() {
    if (_activityMinutes.isEmpty) {
      return _card(
        child: Text('Sin datos de sesión todavía.',
            style: TextStyle(color: Colors.white.withOpacity(0.4))),
      );
    }
    return _card(
      child: Column(
        children: (_activityMinutes.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 110,
                          child: Text(e.key.displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 13))),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: e.value / (_activeMinutes == 0 ? 1 : _activeMinutes),
                          backgroundColor: Colors.white12,
                          color: Colors.greenAccent,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${e.value} min',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _realtimeDebugCard() {
    return _card(
      color: const Color(0xFF0D1F35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricRow('Actividad', _lastHar?.activity.displayName ?? '—'),
          _metricRow('Confianza HAR', _lastHar != null
              ? '${(_lastHar!.confidence * 100).toStringAsFixed(1)}%'
              : '—'),
          _metricRow('SVM actual', '${_svmG.toStringAsFixed(3)} g'),
          _metricRow('CNN prob. caída', _lastFall != null
              ? '${(_lastFall!.cnnProbability * 100).toStringAsFixed(1)}%'
              : '—'),
          _metricRow('Etapa fall', _lastFall?.triggeredStage.toString() ?? '0'),
          _metricRow('Modelo HAR', _harClassifier.isLoaded ? '✓ loaded' : '✗ no disponible'),
          _metricRow('Modelo fall', _fallDetector.isLoaded ? '✓ loaded' : '✗ no disponible'),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // TAB 3 — PRUEBAS
  // ────────────────────────────────────────────────────────────────

  Widget _buildTestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Conexión al backend'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _testButton(
                  label: 'Health check  GET /health',
                  icon: Icons.cloud_outlined,
                  color: Colors.lightBlueAccent,
                  onTap: _testHealth,
                ),
                const SizedBox(height: 8),
                _testButton(
                  label: 'Enviar actividad  POST /events/activity',
                  icon: Icons.send_outlined,
                  color: Colors.greenAccent,
                  onTap: _testPostActivity,
                ),
                const SizedBox(height: 8),
                _testButton(
                  label: 'Enviar caída  POST /events/fall',
                  icon: Icons.warning_amber_outlined,
                  color: Colors.orangeAccent,
                  onTap: _testPostFall,
                ),
                const SizedBox(height: 8),
                _testButton(
                  label: 'VitaPoints  GET /users/{id}/vitapoints',
                  icon: Icons.star_outlined,
                  color: Colors.amber,
                  onTap: _testGetVitaPoints,
                ),
                const SizedBox(height: 8),
                _testButton(
                  label: 'Último modelo  GET /models/latest',
                  icon: Icons.system_update_outlined,
                  color: Colors.purpleAccent,
                  onTap: _testGetLatestModel,
                ),
                const SizedBox(height: 8),
                _testButton(
                  label: 'Borrar datos  DELETE /users/{id}/data',
                  icon: Icons.delete_forever_outlined,
                  color: Colors.redAccent,
                  onTap: _testDeleteUserData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Inferencia on-device'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _testButton(
                  label: 'HAR — datos de caminar',
                  icon: Icons.directions_walk,
                  color: Colors.greenAccent,
                  onTap: () => _testHar('walking'),
                ),
                const SizedBox(height: 8),
                _testButton(
                  label: 'HAR — datos de correr',
                  icon: Icons.directions_run,
                  color: Colors.greenAccent,
                  onTap: () => _testHar('running'),
                ),
                const SizedBox(height: 8),
                _testButton(
                  label: 'HAR — datos estático',
                  icon: Icons.accessibility_new,
                  color: Colors.white54,
                  onTap: () => _testHar('static'),
                ),
                const SizedBox(height: 8),
                _testButton(
                  label: 'Fall detector — caída simulada (SVM 6g)',
                  icon: Icons.personal_injury_outlined,
                  color: Colors.redAccent,
                  onTap: _testFallDetectorFall,
                ),
                const SizedBox(height: 8),
                _testButton(
                  label: 'Fall detector — ADL normal (sin caída)',
                  icon: Icons.shield_outlined,
                  color: Colors.tealAccent,
                  onTap: _testFallDetectorAdl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_testRunning)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.15),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: () => setState(() {
                  _cancelRequested = true;
                  _testRunning = false;
                }),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancelar prueba en curso'),
              ),
            ),
          if (_testResults.isNotEmpty) ...[
            Row(
              children: [
                Expanded(child: _sectionTitle('Resultados')),
                TextButton(
                  onPressed: () => setState(() => _testResults.clear()),
                  child: const Text('Limpiar', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              ],
            ),
            ..._testResults.reversed.map(_buildTestResultCard),
          ],
        ],
      ),
    );
  }

  Widget _testButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.12),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.3)),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onPressed: _testRunning ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
      );

  Widget _buildTestResultCard(_TestResult r) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _card(
          color: r.ok ? const Color(0xFF0D2D1A) : const Color(0xFF2D0D0D),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(r.ok ? Icons.check_circle_outline : Icons.error_outline,
                      color: r.ok ? Colors.greenAccent : Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(r.name,
                        style: TextStyle(
                            color: r.ok ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  Text(r.elapsed,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              Text(r.detail,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
        ),
      );

  void _addResult(_TestResult r) {
    if (mounted) setState(() => _testResults.add(r));
  }

  Future<void> _testHealth() async {
    setState(() { _testRunning = true; _cancelRequested = false; });
    final sw = Stopwatch()..start();
    try {
      final ok = await _api.checkHealth();
      sw.stop();
      if (_cancelRequested) return;
      if (mounted) setState(() => _backendConnected = ok);
      _addResult(_TestResult(
        name: 'GET /health',
        ok: ok,
        detail: ok ? 'status: ok  db: ok  redis: ok  minio: ok' : 'Sin respuesta — backend no alcanzable',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
    } catch (e) {
      _addResult(_TestResult(name: 'GET /health', ok: false, detail: 'Error: $e', elapsed: '${sw.elapsedMilliseconds} ms'));
    } finally {
      if (mounted && !_cancelRequested) setState(() => _testRunning = false);
    }
  }

  Future<void> _testPostActivity() async {
    setState(() { _testRunning = true; _cancelRequested = false; });
    final sw = Stopwatch()..start();
    try {
      final res = await _api.postActivity(activity: 'walking', durationSeconds: 60);
      sw.stop();
      if (_cancelRequested) return;
      final ok = res != null;
      _addResult(_TestResult(
        name: 'POST /events/activity  (walking, 60s)',
        ok: ok,
        detail: ok
            ? 'vitapoints_earned: ${res['vitapoints_earned']}\n'
              'total_vitapoints:  ${res['total_vitapoints']}\n'
              'streak_days:       ${res['streak_days']}\n'
              'level:             ${res['level']}'
            : 'Sin respuesta — backend no alcanzable',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
    } catch (e) {
      _addResult(_TestResult(name: 'POST /events/activity', ok: false, detail: 'Error: $e', elapsed: '${sw.elapsedMilliseconds} ms'));
    } finally {
      if (mounted && !_cancelRequested) setState(() => _testRunning = false);
    }
  }

  Future<void> _testPostFall() async {
    setState(() { _testRunning = true; _cancelRequested = false; });
    final sw = Stopwatch()..start();
    try {
      final fallId = await _api.postFall(stage: 2, svmPeak: 5.4);
      sw.stop();
      if (_cancelRequested) return;
      final ok = fallId != null;
      _addResult(_TestResult(
        name: 'POST /events/fall  (stage=2, svm=5.4g)',
        ok: ok,
        detail: ok
            ? 'fall_id: $fallId\nstatus: pending → worker esperará 30s ACK'
            : 'Sin respuesta — backend no alcanzable',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
      if (ok) await _api.ackFall(fallId); // auto-ACK so worker doesn't alert
    } catch (e) {
      _addResult(_TestResult(name: 'POST /events/fall', ok: false, detail: 'Error: $e', elapsed: '${sw.elapsedMilliseconds} ms'));
    } finally {
      if (mounted && !_cancelRequested) setState(() => _testRunning = false);
    }
  }

  Future<void> _testHar(String type) async {
    if (!_harClassifier.isLoaded) {
      _addResult(_TestResult(name: 'HAR — $type', ok: false, detail: 'Modelo no cargado', elapsed: '0 ms'));
      return;
    }
    setState(() { _testRunning = true; _cancelRequested = false; });
    final sw = Stopwatch()..start();
    try {
      final window = List.generate(128, (i) {
        final t = i / 50.0;
        switch (type) {
          case 'walking':
            return [
              0.15 * sin(2 * pi * 1.8 * t),
              0.20 * sin(2 * pi * 1.8 * t + 1.0),
              1.0 + 0.10 * sin(2 * pi * 3.6 * t),
              0.05 * sin(2 * pi * 1.8 * t),
              0.08 * sin(2 * pi * 1.8 * t),
              0.04 * sin(2 * pi * 1.8 * t),
            ];
          case 'running':
            return [
              0.40 * sin(2 * pi * 2.8 * t),
              0.50 * sin(2 * pi * 2.8 * t + 1.0),
              1.0 + 0.30 * sin(2 * pi * 5.6 * t),
              0.20 * sin(2 * pi * 2.8 * t),
              0.25 * sin(2 * pi * 2.8 * t),
              0.15 * sin(2 * pi * 2.8 * t),
            ];
          default: // static
            return [0.01, 0.01, 1.0, 0.0, 0.0, 0.0];
        }
      });
      final result = _harClassifier.classify(window);
      sw.stop();
      if (_cancelRequested) return;
      _addResult(_TestResult(
        name: 'HAR model — datos sintéticos ($type)',
        ok: result != null,
        detail: result != null
            ? 'Predicción: ${result.activity.displayName}\n'
              'Confianza:  ${(result.confidence * 100).toStringAsFixed(1)}%\n'
              'VitaPoints: ${result.vitaPointsPerMinute} pts/min'
            : 'Clasificador devolvió null',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
    } catch (e) {
      _addResult(_TestResult(name: 'HAR — $type', ok: false, detail: 'Error: $e', elapsed: '${sw.elapsedMilliseconds} ms'));
    } finally {
      if (mounted && !_cancelRequested) setState(() => _testRunning = false);
    }
  }

  Future<void> _testFallDetectorFall() async {
    setState(() { _testRunning = true; _cancelRequested = false; });
    final sw = Stopwatch()..start();
    try {
      // Synthetic fall: flat baseline + sharp 6g spike at sample 50
      final window = List.generate(100, (i) {
        if (i >= 44 && i <= 56) {
          final phase = (i - 44) / 12.0; // 0..1
          final peak = 6.0 * sin(phase * pi); // clean half-sine, 0→6→0
          return [peak, peak * 0.3, 1.0 + peak * 0.5, 0.5, 0.3, 0.2];
        }
        // Post-fall immobility (last 25 samples very still)
        if (i >= 75) return [0.01, 0.01, 1.0, 0.005, 0.005, 0.005];
        return [0.02, 0.02, 1.0, 0.01, 0.01, 0.01];
      });
      final result = _fallDetector.analyze(window);
      sw.stop();
      if (_cancelRequested) return;
      _addResult(_TestResult(
        name: 'Fall detector — caída simulada (pico 6g)',
        ok: result.isFall,
        detail: 'Etapa activada: ${result.triggeredStage}\n'
            'SVM peak:       ${result.svmPeak.toStringAsFixed(3)} g\n'
            'CNN prob:       ${(result.cnnProbability * 100).toStringAsFixed(1)}%\n'
            'Inmovilidad:    ${result.immobilityConfirmed}\n'
            'Umbral SVM:     ${FallDetector.svmThreshold} g',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
    } catch (e) {
      sw.stop();
      _addResult(_TestResult(
        name: 'Fall detector — caída simulada (pico 6g)',
        ok: false,
        detail: 'Excepción en inferencia CNN: $e\n'
            'Stage 1 (SVM) puede haber pasado pero CNN lanzó error.',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
    } finally {
      if (mounted && !_cancelRequested) setState(() => _testRunning = false);
    }
  }

  Future<void> _testGetVitaPoints() async {
    setState(() { _testRunning = true; _cancelRequested = false; });
    final sw = Stopwatch()..start();
    try {
      final vp = await _api.getVitaPoints();
      sw.stop();
      if (_cancelRequested) return;
      final ok = vp != null;
      _addResult(_TestResult(
        name: 'GET /users/{id}/vitapoints',
        ok: ok,
        detail: ok
            ? 'total:       ${vp.total}\n'
              'this_week:   ${vp.thisWeek}\n'
              'streak_days: ${vp.streakDays}\n'
              'level:       ${vp.level}'
            : 'Sin respuesta — backend no alcanzable',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
      if (ok && mounted) {
        setState(() {
          _vitaPoints = vp.total;
          _streakDays = vp.streakDays;
          _level = vp.level;
        });
      }
    } catch (e) {
      _addResult(_TestResult(name: 'GET /users/{id}/vitapoints', ok: false, detail: 'Error: $e', elapsed: '${sw.elapsedMilliseconds} ms'));
    } finally {
      if (mounted && !_cancelRequested) setState(() => _testRunning = false);
    }
  }

  Future<void> _testGetLatestModel() async {
    setState(() { _testRunning = true; _cancelRequested = false; });
    final sw = Stopwatch()..start();
    try {
      final meta = await _api.getLatestModel();
      sw.stop();
      if (_cancelRequested) return;
      final ok = meta != null;
      _addResult(_TestResult(
        name: 'GET /models/latest',
        ok: ok,
        detail: ok
            ? 'name:     ${meta.name}\n'
              'version:  ${meta.version}\n'
              'size_kb:  ${meta.sizeKb}\n'
              'filename: ${meta.filename}'
            : 'Sin modelos en MinIO o backend no alcanzable',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
    } catch (e) {
      _addResult(_TestResult(name: 'GET /models/latest', ok: false, detail: 'Error: $e', elapsed: '${sw.elapsedMilliseconds} ms'));
    } finally {
      if (mounted && !_cancelRequested) setState(() => _testRunning = false);
    }
  }

  Future<void> _testDeleteUserData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D0A0A),
        title: const Text('Borrar datos de demo_user_001',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Esto borra permanentemente los datos del usuario demo en el backend. '
          'Útil para resetear entre demos.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _testRunning = true; _cancelRequested = false; });
    final sw = Stopwatch()..start();
    try {
      final ok = await _api.deleteUserData();
      sw.stop();
      if (_cancelRequested) return;
      _addResult(_TestResult(
        name: 'DELETE /users/{id}/data',
        ok: ok,
        detail: ok
            ? '204 No Content — todos los datos borrados en cascada'
            : 'Sin respuesta — backend no alcanzable',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
      if (ok && mounted) {
        setState(() { _vitaPoints = 0; _streakDays = 0; _level = 'bronze'; });
      }
    } catch (e) {
      _addResult(_TestResult(name: 'DELETE /users/{id}/data', ok: false, detail: 'Error: $e', elapsed: '${sw.elapsedMilliseconds} ms'));
    } finally {
      if (mounted && !_cancelRequested) setState(() => _testRunning = false);
    }
  }

  Future<void> _testFallDetectorAdl() async {
    setState(() { _testRunning = true; _cancelRequested = false; });
    final sw = Stopwatch()..start();
    try {
      final window = List.generate(100, (i) {
        final t = i / 50.0;
        return [
          0.15 * sin(2 * pi * 1.8 * t),
          0.20 * sin(2 * pi * 1.8 * t + 1.0),
          1.0 + 0.10 * sin(2 * pi * 3.6 * t),
          0.05, 0.08, 0.04,
        ];
      });
      final result = _fallDetector.analyze(window);
      sw.stop();
      if (_cancelRequested) return;
      _addResult(_TestResult(
        name: 'Fall detector — caminar normal (sin caída)',
        ok: !result.isFall,
        detail: 'Etapa activada: ${result.triggeredStage}\n'
            'SVM peak:       ${result.svmPeak.toStringAsFixed(3)} g\n'
            'CNN prob:       ${(result.cnnProbability * 100).toStringAsFixed(1)}%\n'
            'Resultado:      ${result.isFall ? "CAÍDA (falso positivo!)" : "Sin caída ✓"}',
        elapsed: '${sw.elapsedMilliseconds} ms',
      ));
    } catch (e) {
      _addResult(_TestResult(name: 'Fall detector — ADL', ok: false, detail: 'Error: $e', elapsed: '${sw.elapsedMilliseconds} ms'));
    } finally {
      if (mounted && !_cancelRequested) setState(() => _testRunning = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Widget _card({required Widget child, Color? color}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? const Color(0xFF1A2D4A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      );

  Widget _metricRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 140,
                child: Text(label,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13))),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Widget _stat(String label, String value, IconData icon, Color color) => Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        ],
      );

  Widget _badgeMetric(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$label: $value',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _FallStageInfo {
  final String stage, name, desc, value;
  final bool active;
  const _FallStageInfo(
      {required this.stage,
      required this.name,
      required this.desc,
      required this.active,
      required this.value});
}

class _TestResult {
  final String name;
  final bool ok;
  final String detail;
  final String elapsed;
  const _TestResult(
      {required this.name,
      required this.ok,
      required this.detail,
      required this.elapsed});
}

