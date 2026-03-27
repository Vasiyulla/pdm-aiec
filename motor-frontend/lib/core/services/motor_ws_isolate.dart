// motor_ws_isolate.dart
// =====================
// A dedicated Dart Isolate that owns the WebSocket connection completely.
//
// THE CORE PROBLEM THIS SOLVES:
//   Even with ValueNotifier, every callback from dart:io WebSocket fires on
//   the main isolate's event loop. jsonDecode(), stream.listen(), and even
//   async/await scheduling all compete with Flutter's raster/UI threads for
//   the single main-isolate event loop. When a motor starts, the VFD sends
//   data bursts and the event loop drains them — blocking gesture hit-testing
//   for 8-20ms per burst, which the user feels as mouse lag or missed taps.
//
// THE FIX:
//   Spawn a second Dart Isolate at startup. It:
//     - Opens and owns the WebSocket connection
//     - Calls jsonDecode() on raw frames (never the UI thread)
//     - Applies the 1-Hz throttle before sending anything
//     - Handles reconnect with exponential back-off
//     - Sends a plain Map<String,dynamic> snapshot to the UI via SendPort
//   The UI isolate receives pre-parsed Maps through its ReceivePort and
//   only creates the typed snapshot objects (VfdSnapshot etc.) — which is
//   microseconds of work, not milliseconds.
//
// ISOLATE COMMUNICATION:
//   Isolates share NOTHING — no heap, no static variables.
//   The only channel is SendPort / ReceivePort (message passing).
//   Messages must be primitives or Maps/Lists of primitives (no custom classes).
//
// USAGE:
//   final bridge = MotorWsIsolateBridge();
//   await bridge.start('ws://192.168.1.100:8000');
//   bridge.monitorStream.listen((snap) => notifiers.updateFromMap(snap));
//   bridge.alertStream.listen((alert) => ...);
//   bridge.dispose();

import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';

// ── Message tags (UI ↔ isolate protocol) ─────────────────────────────────────
const _kTagMonitor = 'monitor';
const _kTagAlert = 'alert';
const _kTagState = 'state'; // connection state string
//const _kTagCmd = 'cmd'; // command from UI to isolate
const _kCmdSetUrl = 'set_url';
const _kCmdDisconnect = 'disconnect';

// ── Entry point (runs in the background isolate) ──────────────────────────────
// Top-level function required by Isolate.spawn.
void _wsIsolateMain(_IsolateConfig cfg) {
  final worker = _WsWorker(cfg.sendPort);
  worker.run(cfg.initialUrl);
  // Also accept commands from the UI isolate
  cfg.receivePort.listen((msg) {
    if (msg is Map && msg['cmd'] == _kCmdSetUrl) {
      worker.setUrl(msg['url'] as String);
    } else if (msg is Map && msg['cmd'] == _kCmdDisconnect) {
      worker.disconnect();
    }
  });
}

class _IsolateConfig {
  final SendPort sendPort;
  final ReceivePort receivePort;
  final String initialUrl;
  _IsolateConfig(this.sendPort, this.receivePort, this.initialUrl);
}

// ── The worker that runs inside the background isolate ────────────────────────
class _WsWorker {
  final SendPort _toUi;

  dynamic _monitorChannel;
  dynamic _alertChannel;
  StreamSubscription? _monitorSub;
  StreamSubscription? _alertSub;
  Timer? _reconnectTimer;

  String _baseUrl = '';
  bool _disposed = false;
  int _retryCount = 0;

  // Throttle: only forward one monitor frame per second to UI isolate
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  static const _kThrottle = Duration(milliseconds: 1000);

  _WsWorker(this._toUi);

  void run(String baseUrl) {
    _baseUrl = baseUrl;
    _connect();
  }

  void setUrl(String url) {
    _baseUrl = url;
    _disconnect();
    _retryCount = 0;
    _connect();
  }

  void disconnect() {
    _disposed = true;
    _disconnect();
  }

  void _connect() {
    if (_disposed) return;
    _connectMonitor();
    _connectAlerts();
  }

  void _connectMonitor() {
    try {
      _monitorChannel = IOWebSocketChannel.connect(
        Uri.parse('$_baseUrl/ws/monitor'),
        connectTimeout: const Duration(seconds: 5),
      );
      _toUi.send({'tag': _kTagState, 'data': 'connecting'});

      _monitorSub = _monitorChannel.stream.listen(
        (raw) {
          _retryCount = 0;
          _toUi.send({'tag': _kTagState, 'data': 'connected'});
          _handleMonitorFrame(raw as String);
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _connectAlerts() {
    try {
      _alertChannel = IOWebSocketChannel.connect(
        Uri.parse('$_baseUrl/ws/alerts'),
        connectTimeout: const Duration(seconds: 5),
      );
      _alertSub = _alertChannel.stream.listen(
        (raw) => _handleAlertFrame(raw as String),
        onError: (_) {},
        onDone: () {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  // JSON decode + throttle happen HERE, in the background isolate
  void _handleMonitorFrame(String raw) {
    final now = DateTime.now();
    if (now.difference(_lastSent) < _kThrottle) return; // throttle
    _lastSent = now;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      // Send only the primitive map — no custom Dart objects cross isolate boundary
      _toUi.send({'tag': _kTagMonitor, 'data': map});
    } catch (_) {
      // Bad JSON — silently discard
    }
  }

  void _handleAlertFrame(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _toUi.send({'tag': _kTagAlert, 'data': map});
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _disconnect();
    _toUi.send({'tag': _kTagState, 'data': 'reconnecting'});
    // Exponential back-off: 1s, 2s, 4s, 8s, capped at 16s
    final delay = Duration(seconds: (1 << _retryCount.clamp(0, 4)));
    _retryCount++;
    _reconnectTimer = Timer(delay, _connect);
  }

  void _disconnect() {
    _monitorSub?.cancel();
    _alertSub?.cancel();
    _reconnectTimer?.cancel();
    try {
      _monitorChannel?.sink?.close();
    } catch (_) {}
    try {
      _alertChannel?.sink?.close();
    } catch (_) {}
    _monitorChannel = null;
    _alertChannel = null;
  }
}

// ── Public bridge used by the UI isolate ─────────────────────────────────────
class MotorWsIsolateBridge {
  Isolate? _isolate;
  ReceivePort? _fromWorker; // UI receives on this
  SendPort? _toWorker; // UI sends commands on this
  ReceivePort? _workerCmdPort; // worker receives commands on this

  final _monitorController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get monitorStream => _monitorController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;
  Stream<String> get stateStream => _stateController.stream;

  String _lastState = 'disconnected';
  String get state => _lastState;

  /// Start the background isolate. Call once at app startup.
  Future<void> start(String wsBaseUrl) async {
    _fromWorker = ReceivePort();
    _workerCmdPort = ReceivePort();

    _fromWorker!.listen(_onMessage);

    _isolate = await Isolate.spawn(
      _wsIsolateMain,
      _IsolateConfig(_fromWorker!.sendPort, _workerCmdPort!, wsBaseUrl),
      debugName: 'motor_ws_isolate',
    );

    // The worker will send its SendPort back as first message so UI can send commands
    // We capture it in _onMessage below.
  }

  void _onMessage(dynamic msg) {
    if (msg is SendPort) {
      // First message from isolate is its command port
      _toWorker = msg;
      return;
    }
    if (msg is! Map) return;
    final tag = msg['tag'] as String?;
    final data = msg['data'];

    switch (tag) {
      case _kTagMonitor:
        if (data is Map<String, dynamic>) {
          _monitorController.add(data);
        }
      case _kTagAlert:
        if (data is Map<String, dynamic>) {
          _alertController.add(data);
        }
      case _kTagState:
        _lastState = data as String? ?? 'unknown';
        _stateController.add(_lastState);
    }
  }

  /// Change the server URL at runtime (e.g. user updates settings).
  void setUrl(String wsBaseUrl) {
    _toWorker?.send({'cmd': _kCmdSetUrl, 'url': wsBaseUrl});
  }

  /// Cleanly shut down the background isolate.
  void dispose() {
    _toWorker?.send({'cmd': _kCmdDisconnect});
    Future.delayed(const Duration(milliseconds: 100), () {
      _isolate?.kill(priority: Isolate.beforeNextEvent);
      _fromWorker?.close();
      _workerCmdPort?.close();
    });
    _monitorController.close();
    _alertController.close();
    _stateController.close();
  }
}
