// VFD (Variable Frequency Drive) Data
export interface VFDData {
  rpm: number;
  frequency: number;
  voltage: number;
  current: number;
  power: number;
  phase_r: number;
  phase_y: number;
  phase_b: number;
  temperature: number;
  status: 'running' | 'stopped' | 'fault';
  fault_code?: string;
}

// PZEM Data (Power Meter)
export interface PZEMData {
  voltage: number;
  current: number;
  power: number;
  energy: number;
  frequency: number;
  power_factor: number;
}

// Combined Monitor Data
export interface MonitorData {
  vfd: VFDData;
  pzem: PZEMData;
  timestamp: number;
}

// Alert Data
export interface AlertData {
  id: string;
  type: 'danger' | 'warning' | 'info';
  title: string;
  message: string;
  timestamp: number;
  read: boolean;
  source: string;
}

// Control Command
export interface ControlCommand {
  motor_id: string;
  command: 'start' | 'stop' | 'speed_control';
  speed?: number;
  duration?: number;
}

// Analytics Data
export interface AnalyticsData {
  timestamp: number;
  rpm: number;
  power: number;
  current: number;
  temperature: number;
  efficiency: number;
}

// Dashboard State
export interface DashboardState {
  connected: boolean;
  lastUpdate: number;
  data: MonitorData | null;
  alerts: AlertData[];
  controlStatus: {
    motor_running: boolean;
    speed_setpoint: number;
  };
}
