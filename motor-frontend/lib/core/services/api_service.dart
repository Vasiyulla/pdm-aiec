// ============================================================
//  api_service.dart  —  REST client for FastAPI motor-backend
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/motor_models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  String _baseUrl = 'http://localhost:8000';

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  Map<String, dynamic> _parse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode, res.body);
  }

  // ── Health ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getHealth() => _get('/health');

  // ── Ports ─────────────────────────────────────────────────────────
  Future<List<String>> getPorts() async {
    final data = await _get('/api/ports');
    final ports = data['ports'] as List<dynamic>? ?? [];
    return ports.map((p) => p['device'].toString()).toList();
  }

  // ── Connect / Disconnect ─────────────────────────────────────────
  Future<Map<String, dynamic>> connect({
    String? vfdPort,
    String? pzemPort,
    int vfdBaud = 9600,
    int pzemBaud = 9600,
    bool simulate = false,
  }) =>
      _post('/api/connect', {
        if (vfdPort != null) 'vfd_port': vfdPort,
        if (pzemPort != null) 'pzem_port': pzemPort,
        'vfd_baud': vfdBaud,
        'pzem_baud': pzemBaud,
        'simulate': simulate,
      });

  Future<Map<String, dynamic>> disconnect() => _post('/api/disconnect');

  // ── Status ────────────────────────────────────────────────────────
  Future<DeviceStatus> getStatus() async {
    final data = await _get('/api/status');
    return DeviceStatus.fromJson(data);
  }

  // ── Motor Commands ────────────────────────────────────────────────
  Future<Map<String, dynamic>> startMotor({
    String direction = 'forward',
    double? frequency,
    double? targetRpm,
  }) =>
      _post('/api/motor/start', {
        'direction': direction,
        if (frequency != null) 'frequency': frequency,
        if (targetRpm != null) 'target_rpm': targetRpm,
      });

  Future<Map<String, dynamic>> stopMotor() => _post('/api/motor/stop');

  Future<Map<String, dynamic>> eStop() => _post('/api/motor/estop');

  Future<Map<String, dynamic>> resetFault() => _post('/api/motor/reset');

  Future<Map<String, dynamic>> setFrequency(double hz) =>
      _post('/api/motor/frequency', {'frequency': hz});

  Future<Map<String, dynamic>> setOcThreshold(double amps) =>
      _post('/api/motor/oc-threshold', {'threshold_amps': amps});

  // ── Monitor ───────────────────────────────────────────────────────
  Future<MonitorData> getMonitor() async {
    final data = await _get('/api/monitor');
    return MonitorData.fromJson(data);
  }

  // ── History ───────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getHistory({
    double? startTs,
    double? endTs,
    int limit = 500,
  }) async {
    var path = '/api/history?limit=$limit';
    if (startTs != null) path += '&start_ts=$startTs';
    if (endTs != null) path += '&end_ts=$endTs';
    final data = await _get(path);
    final rows = data['rows'] as List<dynamic>? ?? [];
    return rows.cast<Map<String, dynamic>>();
  }

  // ── Logs ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLogs({int limit = 100}) async {
    final data = await _get('/api/logs?limit=$limit');
    final logs = data['logs'] as List<dynamic>? ?? [];
    return logs.cast<Map<String, dynamic>>();
  }

  // ── Alerts ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAlerts() => _get('/api/alerts');

  Future<Map<String, dynamic>> acknowledgeAlert(String alertId) =>
      _post('/api/alerts/$alertId/ack');

  // ── Reports ───────────────────────────────────────────────────────
  String getReportDownloadUrl() => '$_baseUrl/api/reports/export';
}
