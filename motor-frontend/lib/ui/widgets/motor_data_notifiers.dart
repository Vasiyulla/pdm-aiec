// motor_data_notifiers_v2.dart
// ============================
// Adds updateFromMap(Map<String,dynamic>) which is what MotorProvider v4
// calls when data arrives from the background isolate.
//
// Reading directly from the raw Map avoids constructing a MonitorData object
// only to immediately deconstruct it — saves ~5-10 allocations per frame.

import 'package:flutter/foundation.dart';
import '../../core/models/motor_models.dart';
import 'dart:collection';

// ── Snapshot types (same as v1) ───────────────────────────────────────────────

class VfdSnapshot {
  final double setFreq, outFreq, outVolt, outCurr, power, pf, inpVolt, proxRpm;
  final int motorRpm;

  const VfdSnapshot({
    this.setFreq = 0,
    this.outFreq = 0,
    this.outVolt = 0,
    this.outCurr = 0,
    this.power = 0,
    this.pf = 0,
    this.inpVolt = 0,
    this.proxRpm = 0,
    this.motorRpm = 0,
  });
}

class PzemSnapshot {
  final double voltage, current, power, freq, pf;
  const PzemSnapshot({
    this.voltage = 0,
    this.current = 0,
    this.power = 0,
    this.freq = 0,
    this.pf = 0,
  });
}

class ChartSnapshot {
  final List<double> rpm, current, freq, power, torque;
  const ChartSnapshot({
    this.rpm = const [],
    this.current = const [],
    this.freq = const [],
    this.power = const [],
    this.torque = const [],
  });
}

class MotorStateSnapshot {
  final String state, command;
  final bool connected, deviceConnected;
  const MotorStateSnapshot({
    this.state = 'STOPPED',
    this.command = 'idle',
    this.connected = false,
    this.deviceConnected = false,
  });
}

// ── Helper: safe numeric read from dynamic map value ─────────────────────────
double _d(dynamic v, [double fallback = 0.0]) =>
    v == null ? fallback : (v as num).toDouble();
int _i(dynamic v, [int fallback = 0]) =>
    v == null ? fallback : (v as num).toInt();

// ── Notifier bag ─────────────────────────────────────────────────────────────

class MotorDataNotifiers {
  final vfd = ValueNotifier<VfdSnapshot>(const VfdSnapshot());
  final pzem = ValueNotifier<PzemSnapshot>(const PzemSnapshot());
  final charts = ValueNotifier<ChartSnapshot>(const ChartSnapshot());
  final motorState =
      ValueNotifier<MotorStateSnapshot>(const MotorStateSnapshot());
  final alerts = ValueNotifier<List<AlertModel>>([]);
  final errorMsg = ValueNotifier<String?>(null);

  static const _kMax = 60;
  final Queue<double> _rpmQ = Queue();
  final Queue<double> _currQ = Queue();
  final Queue<double> _freqQ = Queue();
  final Queue<double> _powerQ = Queue();
  final Queue<double> _torqueQ = Queue();

  // ── Called from MotorProvider._onMonitorMap (UI isolate, minimal work) ────
  void updateFromMap(Map<String, dynamic> map) {
    final vfdMap = map['vfd'] as Map<String, dynamic>?;
    final pzemMap = map['pzem'] as Map<String, dynamic>?;

    if (vfdMap != null) {
      vfd.value = VfdSnapshot(
        setFreq: _d(vfdMap['set_freq']),
        outFreq: _d(vfdMap['out_freq']),
        outVolt: _d(vfdMap['out_volt']),
        outCurr: _d(vfdMap['out_curr']),
        motorRpm: _i(vfdMap['motor_rpm']),
        power: _d(vfdMap['power']),
        pf: _d(vfdMap['pf']),
        inpVolt: _d(vfdMap['inp_volt']),
        proxRpm: _d(vfdMap['prox_rpm']),
      );
    }

    if (pzemMap != null) {
      pzem.value = PzemSnapshot(
        voltage: _d(pzemMap['voltage']),
        current: _d(pzemMap['current']),
        power: _d(pzemMap['power']),
        freq: _d(pzemMap['freq']),
        pf: _d(pzemMap['pf']),
      );
    }

    _updateCharts(vfdMap, pzemMap);
  }

  void _push(Queue<double> q, double? v) {
    if (v == null || v.isNaN || v.isInfinite) return;
    q.addLast(v);
    if (q.length > _kMax) q.removeFirst();
  }

  void _updateCharts(
    Map<String, dynamic>? vfdMap,
    Map<String, dynamic>? pzemMap,
  ) {
    final rpm = vfdMap != null ? _d(vfdMap['motor_rpm']) : null;
    final curr = vfdMap != null
        ? _d(vfdMap['out_curr'])
        : pzemMap != null
            ? _d(pzemMap['current'])
            : null;
    final freq = vfdMap != null ? _d(vfdMap['out_freq']) : null;
    final power = vfdMap != null
        ? _d(vfdMap['power'])
        : pzemMap != null
            ? _d(pzemMap['power'])
            : null;

    _push(_rpmQ, rpm);
    _push(_currQ, curr);
    _push(_freqQ, freq);
    _push(_powerQ, power);

    final rpmVal = rpm ?? 0;
    final powerVal = power ?? 0;
    if (rpmVal > 10) {
      final torque = powerVal / (2 * 3.14159265 * rpmVal / 60.0);
      _push(_torqueQ, torque.clamp(0, 500));
    } else {
      _push(_torqueQ, 0.0);
    }

    charts.value = ChartSnapshot(
      rpm: _rpmQ.toList(),
      current: _currQ.toList(),
      freq: _freqQ.toList(),
      power: _powerQ.toList(),
      torque: _torqueQ.toList(),
    );
  }

  void dispose() {
    vfd.dispose();
    pzem.dispose();
    charts.dispose();
    motorState.dispose();
    alerts.dispose();
    errorMsg.dispose();
  }
}
