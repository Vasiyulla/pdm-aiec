import { ControlCommand, VFDData, PZEMData, AlertData, AnalyticsData } from './types';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

// VFD Commands
export async function startMotor(motorId: string): Promise<{ success: boolean; message: string }> {
  const response = await fetch(`${API_BASE}/vfd/start`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ motor_id: motorId }),
  });
  return response.json();
}

export async function stopMotor(motorId: string): Promise<{ success: boolean; message: string }> {
  const response = await fetch(`${API_BASE}/vfd/stop`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ motor_id: motorId }),
  });
  return response.json();
}

export async function setSpeed(motorId: string, speed: number): Promise<{ success: boolean; message: string }> {
  const response = await fetch(`${API_BASE}/vfd/speed`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ motor_id: motorId, speed }),
  });
  return response.json();
}

// Data Endpoints
export async function getLatestVFDData(): Promise<VFDData> {
  const response = await fetch(`${API_BASE}/vfd/latest`, {
    headers: { 'Content-Type': 'application/json' },
  });
  return response.json();
}

export async function getLatestPZEMData(): Promise<PZEMData> {
  const response = await fetch(`${API_BASE}/pzem/latest`, {
    headers: { 'Content-Type': 'application/json' },
  });
  return response.json();
}

export async function getAlerts(limit: number = 50): Promise<AlertData[]> {
  const response = await fetch(`${API_BASE}/alerts?limit=${limit}`, {
    headers: { 'Content-Type': 'application/json' },
  });
  return response.json();
}

export async function getAnalytics(
  startTime: number,
  endTime: number,
): Promise<AnalyticsData[]> {
  const response = await fetch(
    `${API_BASE}/analytics?start=${startTime}&end=${endTime}`,
    {
      headers: { 'Content-Type': 'application/json' },
    },
  );
  return response.json();
}

export async function markAlertAsRead(alertId: string): Promise<{ success: boolean }> {
  const response = await fetch(`${API_BASE}/alerts/${alertId}/read`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  });
  return response.json();
}
