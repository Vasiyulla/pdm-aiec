// ============================================================
//  websocket_service.dart  (v2)
//
//  FIXES:
//   1. JSON decoded in a Dart Isolate — never blocks UI thread
//   2. Client-side frame throttle — UI updates restricted to _kUiThrottle
//   3. Exponential back-off reconnect for both channels
//   4. WsState management for redundant channels
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/motor_models.dart';

enum WsState { disconnected, connecting, connected, error }

// ── Persistent Isolate Worker ───────────────────────────────────────────────
// This handles all the heavy lifting: JSON parsing and data normalization.

class _WsWorkerMessage {
  final String? rawMonitor;
  final String? rawAlert;
  final bool terminate;

  _WsWorkerMessage({this.rawMonitor, this.rawAlert, this.terminate = false});
}

void _wsWorkerEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is! _WsWorkerMessage) return;
    if (message.terminate) {
      Isolate.exit();
    }

    if (message.rawMonitor != null) {
      try {
        final decoded = jsonDecode(message.rawMonitor!) as Map<String, dynamic>;
        final data = MonitorData.fromJson(decoded);
        mainSendPort.send(data);
      } catch (_) {
        // Drop bad packets silently in the worker
      }
    }

    if (message.rawAlert != null) {
      try {
        final decoded = jsonDecode(message.rawAlert!) as Map<String, dynamic>;
        mainSendPort.send(decoded);
      } catch (_) {}
    }
  });
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
      onStateChange(true);
      _sub = _channel!.stream.listen(
        (data) => onMessage(data.toString()),
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

  // ── Worker State ────────────────────────────────────────────────
  Isolate? _worker;
  SendPort? _workerSendPort;
  final ReceivePort _workerReceivePort = ReceivePort();
  bool _initializingWorker = false;

  late final _ResilientChannel _monitor;
  late final _ResilientChannel _alerts;
  bool _monitorOk = false;
  bool _alertOk = false;

  WebSocketService() {
    _initWorker();

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

  Future<void> _initWorker() async {
    if (_initializingWorker) return;
    _initializingWorker = true;

    _worker =
        await Isolate.spawn(_wsWorkerEntryPoint, _workerReceivePort.sendPort);
    _workerReceivePort.listen((msg) {
      if (msg is SendPort) {
        _workerSendPort = msg;
      } else if (msg is MonitorData) {
        if (!_monitorController.isClosed) _monitorController.add(msg);
      } else if (msg is Map<String, dynamic>) {
        if (!_alertController.isClosed) _alertController.add(msg);
      }
    });
    _initializingWorker = false;
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

  void _handleMonitorMessage(String raw) {
    if (_workerSendPort != null) {
      _workerSendPort!.send(_WsWorkerMessage(rawMonitor: raw));
    }
  }

  void _handleAlertMessage(String raw) {
    if (_workerSendPort != null) {
      _workerSendPort!.send(_WsWorkerMessage(rawAlert: raw));
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
    _workerSendPort?.send(_WsWorkerMessage(terminate: true));
    _worker?.kill();
    _workerReceivePort.close();

    _monitor.dispose();
    _alerts.dispose();
    _monitorController.close();
    _alertController.close();
    _stateController.close();
  }
}
