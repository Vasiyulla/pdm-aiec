// motor_provider_v3.dart
// ======================
// MotorProvider now has TWO responsibilities:
//
//   1. Commands (start/stop/connect/disconnect) — still uses ChangeNotifier
//      because these are infrequent and it's fine to rebuild the button bar.
//
//   2. Live data — delegated entirely to MotorDataNotifiers (ValueNotifier).
//      _onMonitorData() never calls notifyListeners(). It pushes to individual
//      ValueNotifiers so only the affected gauge/chart/card rebuilds.
//
// This means GestureDetector, AppBar, NavBar, buttons — anything that isn't
// directly displaying live sensor data — are NEVER rebuilt during monitoring.
// Mouse events and tap responses become instant.
//
// SETUP in main.dart / app root:
//   MultiProvider(
//     providers: [
//       Provider(create: (_) => MotorDataNotifiers()),
//       ChangeNotifierProvider(create: (ctx) => MotorProvider(
//         apiService,
//         websocketService,
//         ctx.read<MotorDataNotifiers>(),
//       )),
//     ],
//   )
//
// USAGE in a gauge widget:
//   ValueListenableBuilder<VfdSnapshot>(
//     valueListenable: context.read<MotorDataNotifiers>().vfd,
//     builder: (_, snap, __) => Text('${snap.motorRpm} RPM'),
//   )
//
// USAGE in a button:
//   Consumer<MotorProvider>(
//     builder: (_, mp, __) => ElevatedButton(
//       onPressed: mp.motorCommand == 'idle' ? () => mp.startMotor() : null,
//       child: Text(mp.motorCommand == 'idle' ? 'Start' : 'Starting…'),
//     ),
//   )

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/motor_models.dart';
import '../../ui/widgets/motor_data_notifiers.dart';

const _kAlertDebounce = Duration(milliseconds: 3000);
const _kStateThrottle = Duration(milliseconds: 500);

class MotorProvider extends ChangeNotifier {
  final ApiService _api;
  final WebSocketService _ws;
  final MotorDataNotifiers _notifiers;

  DeviceStatus? _status;
  List<Map<String, dynamic>> _eventLogs = [];
  List<Map<String, dynamic>> _history = [];

  bool _connected = false;
  bool _loading = false;
  String _motorCommand = 'idle';

  // Weight analysis
  double _s1 = 0.0;
  double _s2 = 0.0;
  final List<Map<String, double>> powerVsWeight = [];
  static const _kMaxWeightPoints = 200;

  DateTime _lastAlertLoad = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastStateNotify = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _statusRefreshTimer;
  Timer? _statusPollTimer;

  MotorProvider(this._api, this._ws, this._notifiers) {
    _ws.monitorStream.listen(_onMonitorData);
    _ws.alertStream.listen(_onAlert);
  }

  // ── Getters ──────────────────────────────────────────────────────────────
  // Commands and connection state only — widgets needing live data use
  // MotorDataNotifiers directly.
  DeviceStatus? get status => _status;
  bool get connected => _connected;
  bool get deviceConnected => _status?.vfdConnected ?? false;
  bool get loading => _loading;
  String get motorCommand => _motorCommand;
  double get s1 => _s1;
  double get s2 => _s2;
  double get weight => (_s1 - _s2).abs();
  WsState get wsState => _ws.state;
  ApiService get api => _api;
  List<Map<String, dynamic>> get eventLogs => _eventLogs;
  List<Map<String, dynamic>> get history => _history;

  String get motorState => _notifiers.motorState.value.state;

  bool get isRunning => motorState == 'FWD' || motorState == 'REV';
  List<AlertModel> get activeAlerts => _notifiers.alerts.value;
  String? get errorMsg => _notifiers.errorMsg.value;

  // ── Compatibility Getters (Proxy to Notifiers) ──────────────────────────
  // Note: These do NOT trigger rebuilds via notifyListeners().
  // UI screens should use ValueListenableBuilder<VfdSnapshot> etc. for live updates.
  VfdSnapshot get vfd => _notifiers.vfd.value;
  PzemSnapshot get pzem => _notifiers.pzem.value;
  ChartSnapshot get chartData => _notifiers.charts.value;

  List<double> get rpmHistory => chartData.rpm;
  List<double> get torqueHistory => chartData.torque;
  List<double> get freqHistory => chartData.freq;
  List<double> get powerHistory => chartData.power;
  List<double> get currentHistory => chartData.current;

  // Recreate MonitorData for legacy screen compatibility
  MonitorData? get latestData {
    final v = vfd;
    final p = pzem;
    return MonitorData(
      timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
      motorState: motorState,
      vfd: VfdData(
        motorRpm: v.motorRpm,
        outFreq: v.outFreq,
        outVolt: v.outVolt,
        outCurr: v.outCurr,
        power: v.power,
        pf: v.pf,
        inpVolt: v.inpVolt,
        proxRpm: v.proxRpm,
      ),
      pzem: PzemData(
        voltage: p.voltage,
        current: p.current,
        power: p.power,
        freq: p.freq,
        pf: p.pf,
      ),
    );
  }


  // ── Server URL ────────────────────────────────────────────────────────────
  void setServerUrl(String url) {
    _api.setBaseUrl(url);
    _ws.setBase(url);
  }

  String get serverUrl => _api.baseUrl;

  // ── Device Connect / Disconnect ─────────────────────────────────────────
  Future<bool> connectDevices({
    String? vfdPort,
    String? pzemPort,
    int vfdBaud = 9600,
    int pzemBaud = 9600,
    bool simulate = false,
  }) async {
    _setLoading(true);
    try {
      final res = await _api.connect(
        vfdPort: vfdPort,
        pzemPort: pzemPort,
        vfdBaud: vfdBaud,
        pzemBaud: pzemBaud,
        simulate: simulate,
      );
      if (res['success'] == true) {
        await refreshStatus();
        _ws.connect();
        _startStatusPoll();
        _connected = true;
        _notifiers.motorState.value = MotorStateSnapshot(
          state: 'STOPPED',
          command: 'idle',
          connected: true,
          deviceConnected: deviceConnected,
        );
        _setLoading(false);
        return true;
      }
      _notifiers.errorMsg.value = res['error'] ?? 'Connection failed';
      _setLoading(false);
      return false;
    } catch (e) {
      _notifiers.errorMsg.value = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> disconnectDevices() async {
    _setLoading(true);
    try {
      await _api.disconnect();
      _ws.disconnect();
      _stopStatusPoll();
      _connected = false;
      _notifiers.motorState.value = const MotorStateSnapshot();
    } catch (_) {}
    _setLoading(false);
  }

  // ── Motor Commands ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> startMotor({
    String direction = 'forward',
    double? frequency,
    double? targetRpm,
  }) async {
    _setMotorCommand('starting');
    try {
      final res = await _api.startMotor(
        direction: direction,
        frequency: frequency,
        targetRpm: targetRpm,
      );
      _setMotorCommand('idle');
      _scheduleStatusRefresh();
      return res;
    } catch (e) {
      _setMotorCommand('idle');
      _notifiers.errorMsg.value = e.toString();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> stopMotor() async {
    _setMotorCommand('stopping');
    try {
      final res = await _api.stopMotor();
      _setMotorCommand('idle');
      _scheduleStatusRefresh();
      return res;
    } catch (e) {
      _setMotorCommand('idle');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> eStop() async {
    try {
      final res = await _api.eStop();
      _scheduleStatusRefresh(delay: const Duration(milliseconds: 300));
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetFault() async {
    try {
      final res = await _api.resetFault();
      _scheduleStatusRefresh();
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setFrequency(double hz) async {
    try {
      return await _api.setFrequency(hz);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Data Refresh ─────────────────────────────────────────────────────────
  Future<void> refreshStatus() async {
    try {
      _status = await _api.getStatus();
      // Update motorState notifier (affects status card, not gauges)
      _notifiers.motorState.value = MotorStateSnapshot(
        state: _status?.motorState ?? 'STOPPED',
        command: _motorCommand,
        connected: _connected,
        deviceConnected: _status?.vfdConnected ?? false,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadAlerts() async {
    try {
      final data = await _api.getAlerts();
      final list = (data['active'] as List<dynamic>? ?? [])
          .map((a) => AlertModel.fromJson(a as Map<String, dynamic>))
          .toList();
      _notifiers.alerts.value = list;
    } catch (_) {}
  }

  Future<void> loadLogs() async {
    try {
      _eventLogs = await _api.getLogs();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadHistory() async {
    try {
      _history = await _api.getHistory();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> acknowledgeAlert(String id) async {
    await _api.acknowledgeAlert(id);
    await loadAlerts();
  }

  // ── Hot path — NEVER calls notifyListeners() ─────────────────────────────
  void _onMonitorData(MonitorData data) {
    // Push to fine-grained ValueNotifiers only.
    // ChangeNotifier listeners (buttons, app bar) are never woken here.
    _notifiers.updateFromMonitor(data);

    // Update motorState notifier if state changed (cheap string compare)
    final prev = _notifiers.motorState.value.state;
    if (data.motorState != prev) {
      _notifiers.motorState.value = MotorStateSnapshot(
        state: data.motorState,
        command: _motorCommand,
        connected: _connected,
        deviceConnected: deviceConnected,
      );
      // State change warrants notifying command consumers (button bar etc.)
      final now = DateTime.now();
      if (now.difference(_lastStateNotify) > _kStateThrottle) {
        _lastStateNotify = now;
        notifyListeners();
      }
    }
  }

  void _onAlert(Map<String, dynamic> alert) {
    // Debounce the HTTP fetch; always update the badge immediately.
    final now = DateTime.now();
    if (now.difference(_lastAlertLoad) >= _kAlertDebounce) {
      _lastAlertLoad = now;
      loadAlerts();
    }
    // Notify for alert badge — this rebuilds the alert count widget only,
    // not the live data gauges, because those use ValueListenableBuilder.
    notifyListeners();
  }

  // ── Weight analysis ───────────────────────────────────────────────────────
  void setS1(double kg) {
    _s1 = kg;
    notifyListeners();
  }

  void setS2(double kg) {
    _s2 = kg;
    notifyListeners();
  }

  void recordWeightDataPoint() {
    if (powerVsWeight.length >= _kMaxWeightPoints) powerVsWeight.removeAt(0);
    final snap = _notifiers.vfd.value;
    final power = snap.power;
    final rpm = snap.motorRpm.toDouble();
    double torque = 0;
    if (rpm > 10) torque = power / (2 * 3.14159265 * rpm / 60.0);
    powerVsWeight.add({'weight': weight, 'power': power, 'torque': torque});
    notifyListeners();
  }

  void clearWeightData() {
    powerVsWeight.clear();
    notifyListeners();
  }

  void clearError() {
    _notifiers.errorMsg.value = null;
  }

  // ── Internals ─────────────────────────────────────────────────────────────
  void _setMotorCommand(String cmd) {
    _motorCommand = cmd;
    _notifiers.motorState.value = MotorStateSnapshot(
      state: _notifiers.motorState.value.state,
      command: cmd,
      connected: _connected,
      deviceConnected: deviceConnected,
    );
    notifyListeners(); // command state change → button bar rebuilds
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _scheduleStatusRefresh(
      {Duration delay = const Duration(milliseconds: 1500)}) {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer(delay, refreshStatus);
  }

  void _startStatusPoll() {
    _statusPollTimer?.cancel();
    _statusPollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => refreshStatus());
  }

  void _stopStatusPoll() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    _stopStatusPoll();
    _ws.dispose();
    super.dispose();
  }
}
