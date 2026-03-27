// widget_examples.dart
// ====================
// Drop-in examples showing how to consume MotorDataNotifiers
// so each widget only rebuilds when its own data changes.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/widgets/motor_data_notifiers.dart';
import '../models/motor_models.dart';
import 'motor_provider.dart';

// ── 1. RPM Gauge — rebuilds ONLY when VFD data changes ──────────────────────
class RpmGauge extends StatelessWidget {
  const RpmGauge({super.key});

  @override
  Widget build(BuildContext context) {
    final notifiers = context.read<MotorDataNotifiers>();
    return ValueListenableBuilder<VfdSnapshot>(
      valueListenable: notifiers.vfd,
      builder: (_, snap, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${snap.motorRpm}',
                style:
                    const TextStyle(fontSize: 48, fontWeight: FontWeight.w300)),
            const Text('RPM', style: TextStyle(fontSize: 12)),
            Text(
                '${snap.outFreq.toStringAsFixed(1)} Hz  |  ${snap.outCurr.toStringAsFixed(2)} A'),
          ],
        );
      },
    );
  }
}

// ── 2. Power Card — rebuilds ONLY when VFD data changes ─────────────────────
class PowerCard extends StatelessWidget {
  const PowerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VfdSnapshot>(
      valueListenable: context.read<MotorDataNotifiers>().vfd,
      builder: (_, snap, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${snap.power.toStringAsFixed(0)} W',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w300)),
              Text(
                  'PF ${snap.pf.toStringAsFixed(2)}  |  ${snap.outVolt.toStringAsFixed(0)} V'),
              Text('Input: ${snap.inpVolt.toStringAsFixed(0)} V'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 3. PZEM Card — separate notifier, never woken by VFD updates ────────────
class PzemCard extends StatelessWidget {
  const PzemCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PzemSnapshot>(
      valueListenable: context.read<MotorDataNotifiers>().pzem,
      builder: (_, snap, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${snap.voltage.toStringAsFixed(1)} V  ${snap.current.toStringAsFixed(2)} A'),
              Text(
                  '${snap.power.toStringAsFixed(0)} W  |  ${snap.freq.toStringAsFixed(2)} Hz'),
              Text('PF ${snap.pf.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 4. Motor State Badge — uses motorState notifier ──────────────────────────
class MotorStateBadge extends StatelessWidget {
  const MotorStateBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MotorStateSnapshot>(
      valueListenable: context.read<MotorDataNotifiers>().motorState,
      builder: (_, snap, __) {
        final color = switch (snap.state) {
          'FWD' => Colors.green,
          'REV' => Colors.blue,
          'FAULT' => Colors.red,
          _ => Colors.grey,
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(snap.state,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w500, fontSize: 13)),
        );
      },
    );
  }
}

// ── 5. Start/Stop button — uses ChangeNotifier (infrequent rebuilds only) ────
// This widget rebuilds only when motor commands change, NOT on every WS frame.
class MotorControlButton extends StatelessWidget {
  const MotorControlButton({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch here is fine: buttons rebuild only on command-state changes
    // (idle → starting → idle), not on live data, because MotorProvider
    // no longer calls notifyListeners() in _onMonitorData.
    final mp = context.watch<MotorProvider>();
    final busy = mp.motorCommand != 'idle';
    final running = mp.isRunning;

    return ElevatedButton.icon(
      onPressed: busy
          ? null
          : () async {
              if (running) {
                await mp.stopMotor();
              } else {
                await mp.startMotor(frequency: 25.0);
              }
            },
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(running ? Icons.stop : Icons.play_arrow),
      label: Text(switch (mp.motorCommand) {
        'starting' => 'Starting…',
        'stopping' => 'Stopping…',
        _ => running ? 'Stop' : 'Start',
      }),
    );
  }
}

// ── 6. Alert badge — uses alerts ValueNotifier ───────────────────────────────
class AlertBadge extends StatelessWidget {
  const AlertBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AlertModel>>(
      valueListenable: context.read<MotorDataNotifiers>().alerts,
      builder: (_, alerts, __) {
        final count = alerts.length;
        if (count == 0) return const Icon(Icons.notifications_none);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications),
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Text('$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── 7. Error snackbar listener — uses errorMsg ValueNotifier ─────────────────
// Place once high in the tree. Shows a SnackBar without rebuilding anything.
class ErrorListener extends StatefulWidget {
  final Widget child;
  const ErrorListener({super.key, required this.child});

  @override
  State<ErrorListener> createState() => _ErrorListenerState();
}

class _ErrorListenerState extends State<ErrorListener> {
  @override
  void initState() {
    super.initState();
    context.read<MotorDataNotifiers>().errorMsg.addListener(_onError);
  }

  void _onError() {
    final msg = context.read<MotorDataNotifiers>().errorMsg.value;
    if (msg == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
    // Clear after showing
    Future.microtask(() {
      if (mounted) {
        context.read<MotorDataNotifiers>().errorMsg.value = null;
      }
    });
  }

  @override
  void dispose() {
    context.read<MotorDataNotifiers>().errorMsg.removeListener(_onError);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── 8. Multi-provider setup in main.dart ─────────────────────────────────────
//
// void main() {
//   final apiService = ApiService();
//   final wsService  = WebSocketService();
//   final notifiers  = MotorDataNotifiers();
//
//   runApp(
//     MultiProvider(
//       providers: [
//         // ValueNotifiers first — no dependency on MotorProvider
//         Provider<MotorDataNotifiers>.value(value: notifiers),
//
//         // MotorProvider receives the notifiers bag
//         ChangeNotifierProvider(
//           create: (_) => MotorProvider(apiService, wsService, notifiers),
//         ),
//       ],
//       child: ErrorListener(child: MyApp()),
//     ),
//   );
// }
