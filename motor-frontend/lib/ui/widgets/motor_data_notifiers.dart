// motor_data_notifiers.dart
// =========================
// Fine-grained ValueNotifiers for live motor data.
//
// WHY THIS EXISTS:
//   ChangeNotifier.notifyListeners() is a broadcast: every Consumer/Selector
//   that listens to MotorProvider rebuilds, including heavy chart widgets and
//   the gesture detector layer. That full-tree relayout is why the mouse feels
//   frozen — Flutter has to re-hit-test the entire widget tree after every
//   relayout pass, which happens up to 2× per second with a ChangeNotifier.
//
//   ValueNotifier<T> only rebuilds the single ValueListenableBuilder that
//   wraps the widget that actually uses that data. Everything else — including
//   GestureDetectors, buttons, and charts that haven't changed — stays
//   completely untouched between frames.
//
// USAGE (in a widget):
//   ValueListenableBuilder<VfdSnapshot>(
//     valueListenable: context.read<MotorDataNotifiers>().vfd,
//     builder: (ctx, snap, _) => RpmGauge(rpm: snap.motorRpm),
//   )

import 'package:flutter/foundation.dart';
import '../../core/models/motor_models.dart';
import 'dart:collection';

// ── Lightweight snapshots (immutable value objects) ──────────────────────────
// Using plain classes instead of full MonitorData so equality checks are fast.

class VfdSnapshot {
  final double setFreq;
  final double outFreq;
  final double outVolt;
  final double outCurr;
  final int motorRpm;
  final double power;
  final double pf;
  final double inpVolt;
  final double proxRpm;

  const VfdSnapshot({
    this.setFreq = 0,
    this.outFreq = 0,
    this.outVolt = 0,
    this.outCurr = 0,
    this.motorRpm = 0,
    this.power = 0,
    this.pf = 0,
    this.inpVolt = 0,
    this.proxRpm = 0,
  });

  factory VfdSnapshot.fromVfdData(VfdData? d) {
    if (d == null) return const VfdSnapshot();
    return VfdSnapshot(
      setFreq: d.setFreq ?? 0,
      outFreq: d.outFreq ?? 0,
      outVolt: d.outVolt ?? 0,
      outCurr: d.outCurr ?? 0,
      motorRpm: d.motorRpm ?? 0,
      power: d.power ?? 0,
      pf: d.pf ?? 0,
      inpVolt: d.inpVolt ?? 0,
      proxRpm: d.proxRpm ?? 0,
    );
  }
}

class PzemSnapshot {
  final double voltage;
  final double current;
  final double power;
  final double freq;
  final double pf;

  const PzemSnapshot({
    this.voltage = 0,
    this.current = 0,
    this.power = 0,
    this.freq = 0,
    this.pf = 0,
  });

  factory PzemSnapshot.fromPzemData(PzemData? d) {
    if (d == null) return const PzemSnapshot();
    return PzemSnapshot(
      voltage: d.voltage ?? 0,
      current: d.current ?? 0,
      power: d.power ?? 0,
      freq: d.freq ?? 0,
      pf: d.pf ?? 0,
    );
  }
}

class ChartSnapshot {
  final List<double> rpm;
  final List<double> current;
  final List<double> freq;
  final List<double> power;
  final List<double> torque;

  const ChartSnapshot({
    this.rpm = const [],
    this.current = const [],
    this.freq = const [],
    this.power = const [],
    this.torque = const [],
  });
}

class MotorStateSnapshot {
  final String state; // STOPPED | FWD | REV | FAULT
  final String command; // idle | starting | stopping
  final bool connected;
  final bool deviceConnected;

  const MotorStateSnapshot({
    this.state = 'STOPPED',
    this.command = 'idle',
    this.connected = false,
    this.deviceConnected = false,
  });
}

// ── The notifier bag — provide this once at the app root ─────────────────────

class MotorDataNotifiers {
  // Each notifier only wakes the widget that uses it.
  final vfd = ValueNotifier<VfdSnapshot>(const VfdSnapshot());
  final pzem = ValueNotifier<PzemSnapshot>(const PzemSnapshot());
  final charts = ValueNotifier<ChartSnapshot>(const ChartSnapshot());
  final motorState =
      ValueNotifier<MotorStateSnapshot>(const MotorStateSnapshot());
  final alerts = ValueNotifier<List<AlertModel>>([]);
  final errorMsg = ValueNotifier<String?>(null);

  // Ring buffer backing stores (only updated from one place — MotorProvider)
  static const _kMax = 60;
  final Queue<double> _rpmQ = Queue();
  final Queue<double> _currQ = Queue();
  final Queue<double> _freqQ = Queue();
  final Queue<double> _powerQ = Queue();
  final Queue<double> _torqueQ = Queue();

  // Called by MotorProvider._onMonitorData — never by widgets directly.
  void updateFromMonitor(MonitorData data) {
    vfd.value = VfdSnapshot.fromVfdData(data.vfd);
    pzem.value = PzemSnapshot.fromPzemData(data.pzem);
    _pushChartPoint(data);
    // charts notifier is set inside _pushChartPoint
  }

  void _push(Queue<double> q, double? v) {
    if (v == null || v.isNaN || v.isInfinite) return;
    q.addLast(v);
    if (q.length > _kMax) q.removeFirst();
  }

  void _pushChartPoint(MonitorData data) {
    _push(_rpmQ, data.vfd?.motorRpm?.toDouble());
    _push(_currQ, data.vfd?.outCurr ?? data.pzem?.current);
    _push(_freqQ, data.vfd?.outFreq);
    _push(_powerQ, data.vfd?.power ?? data.pzem?.power);

    final rpm = data.vfd?.motorRpm?.toDouble() ?? 0;
    final power = (data.vfd?.power ?? data.pzem?.power ?? 0).toDouble();
    if (rpm > 10) {
      final torque = power / (2 * 3.14159265 * rpm / 60.0);
      _push(_torqueQ, torque.clamp(0, 500));
    } else {
      _push(_torqueQ, 0.0);
    }

    // Publish a new ChartSnapshot — widgets holding stale list refs won't
    // accidentally see future mutations because toList() copies.
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
