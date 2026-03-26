// ============================================================
//  websocket_service.dart  —  WS streams for live data + alerts
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/motor_models.dart';

enum WsState { disconnected, connecting, connected, error }

class WebSocketService {
  WebSocketChannel? _monitorChannel;
  WebSocketChannel? _alertsChannel;

  final _monitorController = StreamController<MonitorData>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<WsState>.broadcast();

  Stream<MonitorData> get monitorStream => _monitorController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;
  Stream<WsState> get stateStream => _stateController.stream;

  WsState _state = WsState.disconnected;
  WsState get state => _state;

  String _wsBase = 'ws://localhost:8000';

  void setBase(String httpBase) {
    _wsBase = httpBase.replaceFirst('http', 'ws');
    if (_wsBase.endsWith('/')) _wsBase = _wsBase.substring(0, _wsBase.length - 1);
  }

  void connect() {
    _setState(WsState.connecting);
    _connectMonitor();
    _connectAlerts();
  }

  void _connectMonitor() {
    try {
      _monitorChannel = WebSocketChannel.connect(
        Uri.parse('$_wsBase/ws/monitor'),
      );
      _setState(WsState.connected);

      _monitorChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString()) as Map<String, dynamic>;
            _monitorController.add(MonitorData.fromJson(json));
          } catch (_) {}
        },
        onError: (_) => _setState(WsState.error),
        onDone: () => _setState(WsState.disconnected),
      );
    } catch (_) {
      _setState(WsState.error);
    }
  }

  void _connectAlerts() {
    try {
      _alertsChannel = WebSocketChannel.connect(
        Uri.parse('$_wsBase/ws/alerts'),
      );

      _alertsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString()) as Map<String, dynamic>;
            _alertController.add(json);
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void disconnect() {
    _monitorChannel?.sink.close();
    _alertsChannel?.sink.close();
    _monitorChannel = null;
    _alertsChannel = null;
    _setState(WsState.disconnected);
  }

  void _setState(WsState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    disconnect();
    _monitorController.close();
    _alertController.close();
    _stateController.close();
  }
}
