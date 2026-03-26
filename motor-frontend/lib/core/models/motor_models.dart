// ============================================================
//  motor_models.dart  —  Data models matching backend schemas
// ============================================================

class VfdData {
  final double? setFreq;
  final double? outFreq;
  final double? outVolt;
  final double? outCurr;
  final int? motorRpm;
  final double? power;
  final double? pf;
  final double? inpVolt;
  final double? proxRpm;
  final double? phaseR;
  final double? phaseY;
  final double? phaseB;
  final String? source;

  const VfdData({
    this.setFreq,
    this.outFreq,
    this.outVolt,
    this.outCurr,
    this.motorRpm,
    this.power,
    this.pf,
    this.inpVolt,
    this.proxRpm,
    this.phaseR,
    this.phaseY,
    this.phaseB,
    this.source,
  });

  factory VfdData.fromJson(Map<String, dynamic> j) => VfdData(
    setFreq: (j['set_freq'] as num?)?.toDouble(),
    outFreq: (j['out_freq'] as num?)?.toDouble(),
    outVolt: (j['out_volt'] as num?)?.toDouble(),
    outCurr: (j['out_curr'] as num?)?.toDouble(),
    motorRpm: (j['motor_rpm'] as num?)?.toInt(),
    power: (j['power'] as num?)?.toDouble(),
    pf: (j['pf'] as num?)?.toDouble(),
    inpVolt: (j['inp_volt'] as num?)?.toDouble(),
    proxRpm: (j['prox_rpm'] as num?)?.toDouble(),
    phaseR: (j['phase_r'] as num?)?.toDouble(),
    phaseY: (j['phase_y'] as num?)?.toDouble(),
    phaseB: (j['phase_b'] as num?)?.toDouble(),
    source: j['source'] as String?,
  );
}

class PzemData {
  final double? voltage;
  final double? current;
  final double? power;
  final double? energy;
  final double? freq;
  final double? pf;

  const PzemData({
    this.voltage, this.current, this.power,
    this.energy, this.freq, this.pf,
  });

  factory PzemData.fromJson(Map<String, dynamic> j) => PzemData(
    voltage: (j['voltage'] as num?)?.toDouble(),
    current: (j['current'] as num?)?.toDouble(),
    power: (j['power'] as num?)?.toDouble(),
    energy: (j['energy'] as num?)?.toDouble(),
    freq: (j['freq'] as num?)?.toDouble(),
    pf: (j['pf'] as num?)?.toDouble(),
  );
}

class MonitorData {
  final double timestamp;
  final String motorState;
  final VfdData? vfd;
  final PzemData? pzem;
  final String? vfdError;

  const MonitorData({
    required this.timestamp,
    required this.motorState,
    this.vfd,
    this.pzem,
    this.vfdError,
  });

  factory MonitorData.fromJson(Map<String, dynamic> j) => MonitorData(
    timestamp: (j['timestamp'] as num?)?.toDouble() ??
        DateTime.now().millisecondsSinceEpoch / 1000,
    motorState: j['motor_state'] as String? ?? 'STOPPED',
    vfd: j['vfd'] != null ? VfdData.fromJson(j['vfd'] as Map<String, dynamic>) : null,
    pzem: j['pzem'] != null ? PzemData.fromJson(j['pzem'] as Map<String, dynamic>) : null,
    vfdError: j['vfd_error'] as String?,
  );
}

class DeviceStatus {
  final bool vfdConnected;
  final bool pzemConnected;
  final String motorState;
  final double ocThreshold;
  final bool simulationMode;
  final int wsMonitorClients;
  final int wsAlertClients;
  final double timestamp;

  const DeviceStatus({
    required this.vfdConnected,
    required this.pzemConnected,
    required this.motorState,
    required this.ocThreshold,
    required this.simulationMode,
    required this.wsMonitorClients,
    required this.wsAlertClients,
    required this.timestamp,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> j) => DeviceStatus(
    vfdConnected: j['vfd_connected'] as bool? ?? false,
    pzemConnected: j['pzem_connected'] as bool? ?? false,
    motorState: j['motor_state'] as String? ?? 'STOPPED',
    ocThreshold: (j['oc_threshold'] as num?)?.toDouble() ?? 10.0,
    simulationMode: j['simulation_mode'] as bool? ?? false,
    wsMonitorClients: j['ws_monitor_clients'] as int? ?? 0,
    wsAlertClients: j['ws_alert_clients'] as int? ?? 0,
    timestamp: (j['timestamp'] as num?)?.toDouble() ?? 0,
  );
}

class AlertModel {
  final String id;
  final String type;
  final String message;
  final String severity;
  final double timestamp;
  final bool acknowledged;
  final Map<String, dynamic> data;

  const AlertModel({
    required this.id,
    required this.type,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.acknowledged,
    required this.data,
  });

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
    id: j['id'] as String? ?? '',
    type: j['type'] as String? ?? '',
    message: j['message'] as String? ?? '',
    severity: j['severity'] as String? ?? 'info',
    timestamp: (j['timestamp'] as num?)?.toDouble() ?? 0,
    acknowledged: j['acknowledged'] as bool? ?? false,
    data: j['data'] as Map<String, dynamic>? ?? {},
  );
}

class EventLog {
  final double timestamp;
  final String level;
  final String message;

  const EventLog({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  factory EventLog.fromJson(Map<String, dynamic> j) => EventLog(
    timestamp: (j['timestamp'] as num?)?.toDouble() ?? 0,
    level: j['level'] as String? ?? 'INFO',
    message: j['message'] as String? ?? '',
  );
}
