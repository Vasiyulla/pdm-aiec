// ============================================================
//  motor_provider.dart  —  Motor state + live data management
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/motor_models.dart';

class MotorProvider extends ChangeNotifier {
  final ApiService _api;
  final WebSocketService _ws;

  MonitorData? _latestData;
  DeviceStatus? _status;
  List<AlertModel> _activeAlerts = [];
  List<Map<String, dynamic>> _eventLogs = [];
  List<Map<String, dynamic>> _history = [];

  // Chart data ring buffers (last 60 samples)
  final List<double> rpmHistory = [];
  final List<double> currentHistory = [];
  final List<double> freqHistory = [];
  final List<double> powerHistory = [];
  final List<double> torqueHistory = [];
  static const _maxSamples = 60;

  // Weight-based load analysis (S1 = loaded, S2 = tare)
  double _s1 = 0.0; // kg (spring balance 1)
  double _s2 = 0.0; // kg (spring balance 2)
  final List<Map<String, double>> powerVsWeight = []; // [{weight, power, torque}]

  bool _connected = false;
  bool _loading = false;
  String? _errorMsg;
  String _motorCommand = 'idle'; // idle | starting | stopping

  StreamSubscription? _monitorSub;
  StreamSubscription? _alertSub;
  Timer? _statusTimer;

  MotorProvider(this._api, this._ws) {
    _ws.monitorStream.listen(_onMonitorData);
    _ws.alertStream.listen(_onAlert);
  }

  // ── Getters ──────────────────────────────────────────────────────
  MonitorData? get latestData => _latestData;
  DeviceStatus? get status => _status;
  List<AlertModel> get activeAlerts => _activeAlerts;
  List<Map<String, dynamic>> get eventLogs => _eventLogs;
  List<Map<String, dynamic>> get history => _history;
  bool get connected => _connected;
  bool get deviceConnected => _status?.vfdConnected ?? false;
  bool get loading => _loading;
  String? get errorMsg => _errorMsg;
  String get motorCommand => _motorCommand; // 'idle' | 'starting' | 'stopping'
  double get s1 => _s1;
  double get s2 => _s2;
  double get weight => (_s1 - _s2).abs(); // net load in kg
  String get motorState => _latestData?.motorState ?? _status?.motorState ?? 'STOPPED';
  WsState get wsState => _ws.state;
  ApiService get api => _api;

  bool get isRunning =>
      motorState == 'FWD' || motorState == 'REV';

  // ── Backend URL ──────────────────────────────────────────────────
  void setServerUrl(String url) {
    _api.setBaseUrl(url);
    _ws.setBase(url);
  }

  String get serverUrl => _api.baseUrl;

  // ── Device Connect / Disconnect ─────────────────────────────────
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
        vfdPort: vfdPort, pzemPort: pzemPort,
        vfdBaud: vfdBaud, pzemBaud: pzemBaud,
        simulate: simulate,
      );
      if (res['success'] == true) {
        await refreshStatus();
        _ws.connect();
        _startStatusPoll();
        _connected = true;
        _setLoading(false);
        return true;
      }
      _errorMsg = res['error'] ?? res['message'] ?? 'Connection failed';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMsg = e.toString();
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
      _latestData = null;
    } catch (_) {}
    _setLoading(false);
  }

  // ── Motor Commands ───────────────────────────────────────────────
  Future<Map<String, dynamic>> startMotor({
    String direction = 'forward',
    double? frequency,
    double? targetRpm,
  }) async {
    _motorCommand = 'starting';
    notifyListeners();
    try {
      final res = await _api.startMotor(
        direction: direction, frequency: frequency, targetRpm: targetRpm,
      );
      await refreshStatus();
      _motorCommand = 'idle';
      notifyListeners();
      return res;
    } catch (e) {
      _motorCommand = 'idle';
      _errorMsg = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> stopMotor() async {
    _motorCommand = 'stopping';
    notifyListeners();
    try {
      final res = await _api.stopMotor();
      await refreshStatus();
      _motorCommand = 'idle';
      notifyListeners();
      return res;
    } catch (e) {
      _motorCommand = 'idle';
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> eStop() async {
    try {
      final res = await _api.eStop();
      await refreshStatus();
      notifyListeners();
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetFault() async {
    try {
      final res = await _api.resetFault();
      await refreshStatus();
      notifyListeners();
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setFrequency(double hz) async {
    try {
      final res = await _api.setFrequency(hz);
      notifyListeners();
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Data Refresh ─────────────────────────────────────────────────
  Future<void> refreshStatus() async {
    try {
      _status = await _api.getStatus();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadAlerts() async {
    try {
      final data = await _api.getAlerts();
      final active = (data['active'] as List<dynamic>? ?? [])
          .map((a) => AlertModel.fromJson(a as Map<String, dynamic>))
          .toList();
      _activeAlerts = active;
      notifyListeners();
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

  // ── Internals ─────────────────────────────────────────────────────
  DateTime _lastNotify = DateTime.now();
  static const _notifyThrottle = Duration(milliseconds: 600);

  void _onMonitorData(MonitorData data) {
    final oldState = _latestData?.motorState;
    _latestData = data;
    _appendHistory(data);
    
    // Throttle UI updates for raw data to prevent lag
    final now = DateTime.now();
    if (now.difference(_lastNotify) > _notifyThrottle || 
        data.motorState != oldState) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  void _appendHistory(MonitorData data) {
    void add(List<double> buf, double? v) {
      if (v == null) return;
      buf.add(v);
      if (buf.length > _maxSamples) buf.removeAt(0);
    }

    add(rpmHistory, data.vfd?.motorRpm?.toDouble());
    add(currentHistory, data.vfd?.outCurr ?? data.pzem?.current);
    add(freqHistory, data.vfd?.outFreq);
    add(powerHistory, data.vfd?.power ?? data.pzem?.power);

    // Calculate torque: T = P / ω   where ω = 2π × RPM / 60
    final rpm = data.vfd?.motorRpm?.toDouble() ?? 0;
    final power = data.vfd?.power ?? data.pzem?.power ?? 0;
    if (rpm > 1) {
      final omega = 2 * 3.14159265 * rpm / 60.0;
      final torque = power / omega;
      add(torqueHistory, torque);
    } else {
      add(torqueHistory, 0.0);
    }
  }

  // ── Weight / load analysis ──────────────────────────────────────────
  void setS1(double kg) {
    _s1 = kg;
    notifyListeners();
  }

  void setS2(double kg) {
    _s2 = kg;
    notifyListeners();
  }

  /// Record current power & torque at the current weight setting
  void recordWeightDataPoint() {
    final power = _latestData?.vfd?.power ?? _latestData?.pzem?.power ?? 0;
    final rpm = _latestData?.vfd?.motorRpm?.toDouble() ?? 0;
    double torque = 0;
    if (rpm > 1) {
      final omega = 2 * 3.14159265 * rpm / 60.0;
      torque = power / omega;
    }
    powerVsWeight.add({
      'weight': weight,
      'power': power.toDouble(),
      'torque': torque,
    });
    notifyListeners();
  }

  void clearWeightData() {
    powerVsWeight.clear();
    notifyListeners();
  }

  void _onAlert(Map<String, dynamic> alert) {
    loadAlerts();
    notifyListeners(); // Always notify on new alerts
  }

  void _startStatusPoll() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshStatus();
    });
  }

  void _stopStatusPoll() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void clearError() {
    _errorMsg = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _monitorSub?.cancel();
    _alertSub?.cancel();
    _stopStatusPoll();
    _ws.dispose();
    super.dispose();
  }
}
