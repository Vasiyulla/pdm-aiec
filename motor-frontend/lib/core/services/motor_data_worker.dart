// motor_data_worker.dart (OPTIMIZED - NO UI LAG)
// ==========================================================

import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'dart:collection';
import 'package:web_socket_channel/io.dart';

enum WorkerCommand { setUrl, disconnect, setThrottle }

class WorkerConfig {
  final SendPort uiSendPort;
  final String initialUrl;
  final Duration throttle;

  WorkerConfig({
    required this.uiSendPort,
    required this.initialUrl,
    this.throttle = const Duration(milliseconds: 150), // ✅ FIXED (6–7 FPS)
  });
}

// ─────────────────────────────────────────────────────────

void _processingIsolateEntry(WorkerConfig cfg) {
  final cmdPort = ReceivePort();
  cfg.uiSendPort.send(cmdPort.sendPort);

  final worker = _DataWorker(cfg.uiSendPort, cfg.throttle);
  worker.run(cfg.initialUrl);

  cmdPort.listen((msg) {
    if (msg is! Map) return;

    final cmd = msg['cmd'] as WorkerCommand;

    switch (cmd) {
      case WorkerCommand.setUrl:
        worker.setUrl(msg['url'] as String);
        break;
      case WorkerCommand.disconnect:
        worker.dispose();
        cmdPort.close();
        break;
      case WorkerCommand.setThrottle:
        worker.setThrottle(msg['duration'] as Duration);
        break;
    }
  });
}

// ─────────────────────────────────────────────────────────

class _DataWorker {
  final SendPort _toUi;
  Duration _throttle;

  IOWebSocketChannel? _monCh, _altCh;
  StreamSubscription? _monSub, _altSub;

  String _url = '';

  final Queue<double> _rpmQ = Queue();
  final Queue<double> _currQ = Queue();
  final Queue<double> _freqQ = Queue();
  final Queue<double> _powerQ = Queue();
  final Queue<double> _torqueQ = Queue();

  static const _kMax = 60;

  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  // ✅ FIX: Frame dropping system
  Map<String, dynamic>? _latestPayload;
  bool _isSending = false;

  _DataWorker(this._toUi, this._throttle);

  void setThrottle(Duration d) => _throttle = d;

  void run(String url) {
    _url = url;
    _connect();
  }

  void setUrl(String url) {
    _url = url;
    _close();
    _connect();
  }

  void _connect() {
    try {
      final uri = Uri.parse('$_url/ws/monitor');

      _monCh = IOWebSocketChannel.connect(uri);

      _monSub = _monCh!.stream.listen(
        (raw) => _processRawData(raw as String),
        onError: (_) => _reconnect(),
        onDone: () => _reconnect(),
      );

      _toUi.send({'tag': 'state', 'data': 'connected'});

      _openAlerts();
    } catch (_) {
      _reconnect();
    }
  }

  void _openAlerts() {
    try {
      final uri = Uri.parse('$_url/ws/alerts');

      _altCh = IOWebSocketChannel.connect(uri);

      _altSub = _altCh!.stream.listen((v) {
        try {
          _toUi.send({'tag': 'alert', 'data': jsonDecode(v as String)});
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _processRawData(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;

      // ✅ Throttle
      final now = DateTime.now();
      if (now.difference(_lastSent) < _throttle) return;
      _lastSent = now;

      final vfd = map['vfd'] as Map<String, dynamic>?;
      final pzem = map['pzem'] as Map<String, dynamic>?;

      if (vfd != null || pzem != null) {
        _updateQueues(vfd, pzem);
      }

      final payload = {
        'tag': 'monitor',
        'data': {
          'motor_state': map['motor_state'],
          'timestamp': map['timestamp'],
          'vfd': vfd == null ? null : _vfdSnapshot(vfd),
          'pzem': pzem == null ? null : _pzemSnapshot(pzem),
          'charts': _chartSnapshot(),
        }
      };

      // ✅🔥 CRITICAL FIX: FRAME DROPPING
      _latestPayload = payload;

      if (_isSending) return;

      _isSending = true;

      Future.microtask(() {
        if (_latestPayload != null) {
          _toUi.send(_latestPayload!);
          _latestPayload = null;
        }
        _isSending = false;
      });
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────

  Map<String, dynamic> _vfdSnapshot(Map<String, dynamic> m) => {
        'setFreq': (m['set_freq'] as num?)?.toDouble() ?? 0.0,
        'outFreq': (m['out_freq'] as num?)?.toDouble() ?? 0.0,
        'outVolt': (m['out_volt'] as num?)?.toDouble() ?? 0.0,
        'outCurr': (m['out_curr'] as num?)?.toDouble() ?? 0.0,
        'motorRpm': (m['motor_rpm'] as num?)?.toInt() ?? 0,
        'power': (m['power'] as num?)?.toDouble() ?? 0.0,
        'pf': (m['pf'] as num?)?.toDouble() ?? 0.0,
        'inpVolt': (m['inp_volt'] as num?)?.toDouble() ?? 0.0,
        'proxRpm': (m['prox_rpm'] as num?)?.toDouble() ?? 0.0,
      };

  Map<String, dynamic> _pzemSnapshot(Map<String, dynamic> m) => {
        'voltage': (m['voltage'] as num?)?.toDouble() ?? 0.0,
        'current': (m['current'] as num?)?.toDouble() ?? 0.0,
        'power': (m['power'] as num?)?.toDouble() ?? 0.0,
        'freq': (m['freq'] as num?)?.toDouble() ?? 0.0,
        'pf': (m['pf'] as num?)?.toDouble() ?? 0.0,
      };

  void _updateQueues(Map<String, dynamic>? vfd, Map<String, dynamic>? pzem) {
    final rpm = (vfd?['motor_rpm'] as num?)?.toDouble();
    final curr = (vfd?['out_curr'] as num?)?.toDouble() ??
        (pzem?['current'] as num?)?.toDouble();
    final freq = (vfd?['out_freq'] as num?)?.toDouble();
    final power = (vfd?['power'] as num?)?.toDouble() ??
        (pzem?['power'] as num?)?.toDouble();

    _push(_rpmQ, rpm);
    _push(_currQ, curr);
    _push(_freqQ, freq);
    _push(_powerQ, power);

    if (rpm != null && power != null && rpm > 10) {
      final torque = power / (2 * 3.14159265 * rpm / 60.0);
      _push(_torqueQ, torque);
    } else {
      _push(_torqueQ, 0.0);
    }
  }

  void _push(Queue<double> q, double? v) {
    if (v == null) return;
    q.addLast(v);
    if (q.length > _kMax) q.removeFirst();
  }

  Map<String, dynamic> _chartSnapshot() => {
        'rpm': _rpmQ.toList(),
        'current': _currQ.toList(),
        'freq': _freqQ.toList(),
        'power': _powerQ.toList(),
        'torque': _torqueQ.toList(),
      };

  void _reconnect() {
    _close();
    Future.delayed(const Duration(seconds: 2), _connect);
  }

  void _close() {
    _monSub?.cancel();
    _altSub?.cancel();
    _monCh?.sink.close();
    _altCh?.sink.close();
  }

  void dispose() {
    _close();
  }
}

class MotorDataWorkerBridge {
  Isolate? _procIsolate;
  SendPort? _toProc;
  ReceivePort? _fromProc;

  final _onData = StreamController<Map<String, dynamic>>.broadcast();
  final _onAlert = StreamController<Map<String, dynamic>>.broadcast();
  final _onState = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get dataStream => _onData.stream;
  Stream<Map<String, dynamic>> get alertStream => _onAlert.stream;
  Stream<String> get stateStream => _onState.stream;

  String _state = 'disconnected';
  String get state => _state;

  Future<void> init(String baseUrl) async {
    _fromProc = ReceivePort();

    _fromProc!.listen((msg) {
      if (msg is SendPort) {
        _toProc = msg;
      } else if (msg is Map) {
        final tag = msg['tag'];
        final data = msg['data'];

        if (tag == 'monitor') {
          _onData.add(msg.cast<String, dynamic>());
        } else if (tag == 'alert') {
          _onAlert.add((data as Map).cast<String, dynamic>());
        } else if (tag == 'state') {
          _state = data as String;
          _onState.add(_state);
        }
      }
    });

    _procIsolate = await Isolate.spawn(
      _processingIsolateEntry,
      WorkerConfig(
        uiSendPort: _fromProc!.sendPort,
        initialUrl: baseUrl,
      ),
    );
  }

  void setUrl(String url) {
    _toProc?.send({'cmd': WorkerCommand.setUrl, 'url': url});
  }

  void dispose() {
    _toProc?.send({'cmd': WorkerCommand.disconnect});
    _procIsolate?.kill();
    _fromProc?.close();
  }
}
