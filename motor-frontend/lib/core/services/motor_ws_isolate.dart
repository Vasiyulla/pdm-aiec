// motor_ws_isolate.dart  (v2 — fixed isolate message error)
// ==========================================================
// FIX: _IsolateConfig previously contained a ReceivePort, which is
// unsendable across isolate boundaries. Dart's Isolate.spawn() only
// accepts primitives and SendPort objects in the initial message.
//
// CORRECT PATTERN (two-SendPort handshake):
//   1. UI creates its own ReceivePort (_fromWorker) and passes only
//      its SendPort to the worker via Isolate.spawn().
//   2. Worker creates its own ReceivePort for incoming commands, then
//      immediately sends ITS SendPort back to the UI as the first message.
//   3. UI receives that SendPort and stores it as _toWorker.
//   Both sides now have a SendPort to the other — fully legal.

import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';

// ── Message tags ──────────────────────────────────────────────────────────────
const _kTagMonitor = 'monitor';
const _kTagAlert = 'alert';
const _kTagState = 'state';
const _kCmdSetUrl = 'set_url';
const _kCmdDisconnect = 'disconnect';

// ── _IsolateConfig: ONLY SendPort + primitives — nothing unsendable ───────────
class _IsolateConfig {
  final SendPort uiSendPort; // worker writes back to UI on this
  final String initialUrl;
  _IsolateConfig({required this.uiSendPort, required this.initialUrl});
}

// ── Isolate entry point (must be top-level for Isolate.spawn) ─────────────────
void _wsIsolateEntry(_IsolateConfig cfg) {
  // Worker creates its OWN ReceivePort for commands — never passed via config
  final cmdPort = ReceivePort();

  // Handshake: send worker's SendPort to UI as very first message
  cfg.uiSendPort.send(cmdPort.sendPort);

  final worker = _WsWorker(cfg.uiSendPort);
  worker.run(cfg.initialUrl);

  cmdPort.listen((msg) {
    if (msg is! Map) return;
    switch (msg['cmd'] as String?) {
      case _kCmdSetUrl:
        worker.setUrl(msg['url'] as String);
      case _kCmdDisconnect:
        worker.disconnect();
        cmdPort.close();
    }
  });
}

// ── Worker ────────────────────────────────────────────────────────────────────
class _WsWorker {
  final SendPort _toUi;
  dynamic _monCh, _altCh;
  StreamSubscription? _monSub, _altSub;
  Timer? _retryTimer;
  String _url = '';
  bool _disposed = false;
  int _retries = 0;

  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  static const _throttle = Duration(milliseconds: 1000);

  _WsWorker(this._toUi);

  void run(String url) {
    _url = url;
    _connect();
  }

  void setUrl(String url) {
    _url = url;
    _close();
    _retries = 0;
    _connect();
  }

  void disconnect() {
    _disposed = true;
    _close();
  }

  void _connect() {
    if (_disposed) return;
    _toUi.send({'tag': _kTagState, 'data': 'connecting'});
    _openMonitor();
    _openAlerts();
  }

  void _openMonitor() {
    try {
      _monCh = IOWebSocketChannel.connect(Uri.parse('$_url/ws/monitor'),
          connectTimeout: const Duration(seconds: 5));
      _monSub = _monCh.stream.listen(
        (raw) {
          _retries = 0;
          _onMonitor(raw as String);
        },
        onError: (_) => _retry(),
        onDone: () => _retry(),
        cancelOnError: false,
      );
    } catch (_) {
      _retry();
    }
  }

  void _openAlerts() {
    try {
      _altCh = IOWebSocketChannel.connect(Uri.parse('$_url/ws/alerts'),
          connectTimeout: const Duration(seconds: 5));
      _altSub = _altCh.stream.listen(
        (raw) => _onAlert(raw as String),
        onError: (_) {},
        onDone: () {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  void _onMonitor(String raw) {
    final now = DateTime.now();
    if (now.difference(_lastSent) < _throttle) return;
    _lastSent = now;
    _toUi.send({'tag': _kTagState, 'data': 'connected'});
    try {
      // jsonDecode runs in background isolate — UI thread never touched
      _toUi.send({'tag': _kTagMonitor, 'data': jsonDecode(raw)});
    } catch (_) {}
  }

  void _onAlert(String raw) {
    try {
      _toUi.send({'tag': _kTagAlert, 'data': jsonDecode(raw)});
    } catch (_) {}
  }

  void _retry() {
    if (_disposed) return;
    _close();
    _toUi.send({'tag': _kTagState, 'data': 'reconnecting'});
    final delay = Duration(seconds: (1 << _retries.clamp(0, 4)));
    _retries++;
    _retryTimer = Timer(delay, _connect);
  }

  void _close() {
    _monSub?.cancel();
    _altSub?.cancel();
    _retryTimer?.cancel();
    try {
      _monCh?.sink.close();
    } catch (_) {}
    try {
      _altCh?.sink.close();
    } catch (_) {}
    _monCh = _altCh = null;
  }
}

// ── Bridge used by the UI isolate ─────────────────────────────────────────────
class MotorWsIsolateBridge {
  Isolate? _isolate;
  ReceivePort? _fromWorker;
  SendPort? _toWorker;

  final _monC = StreamController<Map<String, dynamic>>.broadcast();
  final _altC = StreamController<Map<String, dynamic>>.broadcast();
  final _stC = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get monitorStream => _monC.stream;
  Stream<Map<String, dynamic>> get alertStream => _altC.stream;
  Stream<String> get stateStream => _stC.stream;

  String _state = 'disconnected';
  String get state => _state;
  bool _started = false;

  Future<void> start(String wsBase) async {
    if (_started) {
      setUrl(wsBase);
      return;
    }
    _started = true;
    _fromWorker = ReceivePort();
    _fromWorker!.listen(_onMsg);

    _isolate = await Isolate.spawn(
      _wsIsolateEntry,
      _IsolateConfig(
        uiSendPort: _fromWorker!.sendPort, // ✅ SendPort only — no ReceivePort
        initialUrl: wsBase, // ✅ String — primitive
      ),
      debugName: 'motor_ws_isolate',
      errorsAreFatal: false,
    );
  }

  void _onMsg(dynamic msg) {
    // Handshake: first message is the worker's command SendPort
    if (msg is SendPort) {
      _toWorker = msg;
      return;
    }
    if (msg is! Map) return;

    final tag = msg['tag'] as String?;
    final data = msg['data'];
    switch (tag) {
      case _kTagMonitor:
        if (data is Map<String, dynamic> && !_monC.isClosed) _monC.add(data);
      case _kTagAlert:
        if (data is Map<String, dynamic> && !_altC.isClosed) _altC.add(data);
      case _kTagState:
        _state = (data as String?) ?? 'unknown';
        if (!_stC.isClosed) _stC.add(_state);
    }
  }

  void setUrl(String wsBase) =>
      _toWorker?.send({'cmd': _kCmdSetUrl, 'url': wsBase});

  void dispose() {
    if (!_started) return;
    _started = false;
    _toWorker?.send({'cmd': _kCmdDisconnect});
    Future.delayed(const Duration(milliseconds: 200), () {
      _isolate?.kill(priority: Isolate.beforeNextEvent);
      _fromWorker?.close();
      _isolate = _fromWorker = _toWorker = null;
    });
    _monC.close();
    _altC.close();
    _stC.close();
  }
}
