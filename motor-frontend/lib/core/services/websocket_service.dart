// ============================================================
//  websocket_service.dart  (v2)
//
//  FIXES:
//   1. JSON decoded in a Dart Isolate (compute()) — never blocks UI thread
//   2. Client-side frame throttle — UI updates at most once per _kUiHz interval
//   3. Exponential back-off reconnect for both channels
//   4. WsState.connected fires only after the first real message, not on connect()
//   5. Channels reconnect independently — a dropped alert WS doesn't kill monitor
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/motor_models.dart';

// ── How fast the UI is allowed to rebuild from WS data.
// 1 Hz is smooth for a motor dashboard and cheap on the GPU.
// Raise to 500ms if you need snappier charts.
const _kUiHz = Duration(milliseconds: 1000);

enum WsState { disconnected, connecting, connected, error }

// ── Isolate helpers (top-level so compute() can spawn them) ──────────────────

MonitorData? _parseMonitor(String raw) {
  try {
    return MonitorData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _parseAlert(String raw) {
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

// ── Single-channel reconnecting WebSocket ────────────────────────────────────

class _ResilientChannel {
  final String Function() uriBuilder;
  final void Function(String) onMessage;
  final void Function(bool connected) onStateChange;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _timer;
  bool _disposed = false;
  int _retries = 0;

  _ResilientChannel({
    required this.uriBuilder,
    required this.onMessage,
    required this.onStateChange,
  });

  void connect() {
    if (_disposed) return;
    _retries = 0;
    _doConnect();
  }

  void _doConnect() {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(uriBuilder()));
      _sub = _channel!.stream.listen(
        (data) {
          _retries = 0;
          onStateChange(true);
          onMessage(data.toString());
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    onStateChange(false);
    _sub?.cancel();
    _channel?.sink.close();
    // Exponential back-off: 1s, 2s, 4s, 8s, capped at 16s
    final delay = Duration(seconds: (1 << _retries.clamp(0, 4)));
    _retries++;
    _timer = Timer(delay, _doConnect);
  }

  void disconnect() {
    _timer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
  }
}

// ── Public WebSocketService ──────────────────────────────────────────────────

class WebSocketService {
  final _monitorController = StreamController<MonitorData>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<WsState>.broadcast();

  Stream<MonitorData> get monitorStream => _monitorController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;
  Stream<WsState> get stateStream => _stateController.stream;

  WsState _state = WsState.disconnected;
  WsState get state => _state;

  String _wsBase = 'ws://localhost:8000';

  // ── Throttle state ────────────────────────────────────────────────────────
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  late final _ResilientChannel _monitor;
  late final _ResilientChannel _alerts;
  bool _monitorOk = false;
  bool _alertOk = false;

  WebSocketService() {
    _monitor = _ResilientChannel(
      uriBuilder: () => '$_wsBase/ws/monitor',
      onMessage: _handleMonitorMessage,
      onStateChange: (ok) {
        _monitorOk = ok;
        _updateState();
      },
    );

    _alerts = _ResilientChannel(
      uriBuilder: () => '$_wsBase/ws/alerts',
      onMessage: _handleAlertMessage,
      onStateChange: (ok) {
        _alertOk = ok;
        _updateState();
      },
    );
  }

  void setBase(String httpBase) {
    _wsBase = httpBase.replaceFirst(RegExp(r'^http'), 'ws');
    if (_wsBase.endsWith('/')) {
      _wsBase = _wsBase.substring(0, _wsBase.length - 1);
    }
  }

  void connect() {
    _setState(WsState.connecting);
    _monitor.connect();
    _alerts.connect();
  }

  void disconnect() {
    _monitor.disconnect();
    _alerts.disconnect();
    _setState(WsState.disconnected);
  }

  // ── Message handlers (called on the platform thread) ─────────────────────

  Future<void> _handleMonitorMessage(String raw) async {
    // Throttle: drop frames that arrive faster than _kUiHz
    final now = DateTime.now();
    if (now.difference(_lastEmit) < _kUiHz) return;
    _lastEmit = now;

    // Parse in isolate — never blocks the UI thread
    final data = await compute(_parseMonitor, raw);
    if (data != null && !_monitorController.isClosed) {
      _monitorController.add(data);
    }
  }

  Future<void> _handleAlertMessage(String raw) async {
    final data = await compute(_parseAlert, raw);
    if (data != null && !_alertController.isClosed) {
      _alertController.add(data);
    }
  }

  void _updateState() {
    if (_monitorOk || _alertOk) {
      _setState(WsState.connected);
    } else if (_state == WsState.connected) {
      _setState(WsState.error);
    }
  }

  void _setState(WsState s) {
    if (_state == s) return;
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  void dispose() {
    _monitor.dispose();
    _alerts.dispose();
    _monitorController.close();
    _alertController.close();
    _stateController.close();
  }
}
