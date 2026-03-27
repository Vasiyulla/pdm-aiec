// motor_provider_v4.dart
// ======================
// MotorProvider wired to MotorWsIsolateBridge.
// Live data arrives as pre-parsed Map<String,dynamic> from the background
// isolate — the UI thread only converts them to typed snapshots (microseconds).
//
// SETUP in main.dart:
//
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//
//     final notifiers = MotorDataNotifiers();
//     final bridge    = MotorWsIsolateBridge();
//     // Don't start the isolate yet — start it when user connects to a server.
//
//     runApp(
//       MultiProvider(
//         providers: [
//           Provider<MotorDataNotifiers>.value(value: notifiers),
//           Provider<MotorWsIsolateBridge>.value(value: bridge),
//           ChangeNotifierProvider(
//             create: (_) => MotorProvider(ApiService(), bridge, notifiers),
//           ),
//         ],
//         child: const MyApp(),
//       ),
//     );
//   }

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/motor_models.dart';
import '../../ui/widgets/motor_data_notifiers.dart';
import '../../core/services/motor_ws_isolate.dart';

const _kAlertDebounce = Duration(milliseconds: 3000);

class MotorProvider extends ChangeNotifier {
  final ApiService _api;
  final MotorWsIsolateBridge _bridge;
  final MotorDataNotifiers _notifiers;

  DeviceStatus? _status;
  List<Map<String, dynamic>> _eventLogs = [];
  List<Map<String, dynamic>> _history = [];

  bool _connected = false;
  bool _loading = false;
  String _motorCommand = 'idle';
  double _s1 = 0.0;
  double _s2 = 0.0;
  final List<Map<String, double>> powerVsWeight = [];

  DateTime _lastAlertLoad = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _statusRefreshTimer;
  Timer? _statusPollTimer;

  StreamSubscription? _monitorSub;
  StreamSubscription? _alertSub;

  MotorProvider(this._api, this._bridge, this._notifiers) {
    // Subscribe to the background isolate streams.
    // These callbacks run on the UI isolate's event loop but do almost
    // zero work — just field reads and ValueNotifier.value = x.
    _monitorSub = _bridge.monitorStream.listen(_onMonitorMap);
    _alertSub = _bridge.alertStream.listen(_onAlertMap);
  }

  // ── Getters ──────────────────────────────────────────────────────────────
  DeviceStatus? get status => _status;
  bool get connected => _connected;
  bool get deviceConnected => _status?.vfdConnected ?? false;
  bool get loading => _loading;
  String get motorCommand => _motorCommand;
  double get s1 => _s1;
  double get s2 => _s2;
  double get weight => (_s1 - _s2).abs();
  String get wsState => _bridge.state;
  ApiService get api => _api;
  List<Map<String, dynamic>> get eventLogs => _eventLogs;
  List<Map<String, dynamic>> get history => _history;
  String get motorState => _notifiers.motorState.value.state;
  bool get isRunning => motorState == 'FWD' || motorState == 'REV';

  // ── Legacy Compatibility (for older UI code) ──────────────────────────────
  List<AlertModel> get activeAlerts => _notifiers.alerts.value;
  String? get errorMsg => _notifiers.errorMsg.value;

  /// Compatibility getter that constructs a MonitorData snapshot.
  /// Note: New UI code should use [notifiers] directly for better performance.
  MonitorData get latestData => MonitorData(
        timestamp: DateTime.now().millisecondsSinceEpoch / 1000,
        motorState: motorState,
        vfd: VfdData(
          setFreq: _notifiers.vfd.value.setFreq,
          outFreq: _notifiers.vfd.value.outFreq,
          outVolt: _notifiers.vfd.value.outVolt,
          outCurr: _notifiers.vfd.value.outCurr,
          motorRpm: _notifiers.vfd.value.motorRpm,
          power: _notifiers.vfd.value.power,
          pf: _notifiers.vfd.value.pf,
          inpVolt: _notifiers.vfd.value.inpVolt,
          proxRpm: _notifiers.vfd.value.proxRpm,
        ),
        pzem: PzemData(
          voltage: _notifiers.pzem.value.voltage,
          current: _notifiers.pzem.value.current,
          power: _notifiers.pzem.value.power,
          freq: _notifiers.pzem.value.freq,
          pf: _notifiers.pzem.value.pf,
        ),
      );

  // ── Server URL ────────────────────────────────────────────────────────────
  void setServerUrl(String url) {
    _api.setBaseUrl(url);
    // Convert http→ws and tell the background isolate to reconnect
    final wsUrl =
        url.replaceFirst(RegExp(r'^http'), 'ws').replaceAll(RegExp(r'/$'), '');
    _bridge.setUrl(wsUrl);
  }

  String get serverUrl => _api.baseUrl;

  // ── Device Connect / Disconnect ──────────────────────────────────────────
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
        // Start the background WS isolate
        final wsUrl = serverUrl
            .replaceFirst(RegExp(r'^http'), 'ws')
            .replaceAll(RegExp(r'/$'), '');
        await _bridge.start(wsUrl);
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
      _bridge.dispose();
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

  // ── Data Refresh ──────────────────────────────────────────────────────────
  Future<void> refreshStatus() async {
    try {
      _status = await _api.getStatus();
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
      _notifiers.alerts.value = (data['active'] as List<dynamic>? ?? [])
          .map((a) => AlertModel.fromJson(a as Map<String, dynamic>))
          .toList();
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

  // ── Hot path — called from bridge stream, does minimal UI-thread work ─────
  void _onMonitorMap(Map<String, dynamic> map) {
    // updateFromMap does: field reads + ValueNotifier.value = newSnapshot
    // Total CPU time on UI thread: ~50 microseconds
    _notifiers.updateFromMap(map);

    // Check for motor state change
    final newState = (map['motor_state'] as String?) ?? '';
    if (newState.isNotEmpty && newState != _notifiers.motorState.value.state) {
      _notifiers.motorState.value = MotorStateSnapshot(
        state: newState,
        command: _motorCommand,
        connected: _connected,
        deviceConnected: deviceConnected,
      );
      // Only notify ChangeNotifier listeners on state changes (rare)
      notifyListeners();
    }
  }

  void _onAlertMap(Map<String, dynamic> alert) {
    final now = DateTime.now();
    if (now.difference(_lastAlertLoad) >= _kAlertDebounce) {
      _lastAlertLoad = now;
      loadAlerts();
    }
    notifyListeners(); // for badge count only
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
    if (powerVsWeight.length >= 200) powerVsWeight.removeAt(0);
    final vfd = _notifiers.vfd.value;
    final power = vfd.power;
    final rpm = vfd.motorRpm.toDouble();
    final torque = rpm > 10 ? power / (2 * 3.14159265 * rpm / 60.0) : 0.0;
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
    notifyListeners();
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
    _monitorSub?.cancel();
    _alertSub?.cancel();
    _statusRefreshTimer?.cancel();
    _stopStatusPoll();
    super.dispose();
  }
}
