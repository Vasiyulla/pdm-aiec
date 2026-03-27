'use client';

import React, { useEffect, useState } from 'react';
import { useWebSocketMonitor } from '@/lib/hooks/useWebSocketMonitor';
import { useWebSocketAlerts } from '@/lib/hooks/useWebSocketAlerts';
import { MonitorTile } from '@/components/MonitorTile';
import { StatusIndicator } from '@/components/StatusIndicator';
import { ConnectionStatus } from '@/components/ConnectionStatus';
import { DataGrid } from '@/components/DataGrid';
import { AlertCard } from '@/components/AlertCard';
import { VFDData, PZEMData } from '@/lib/types';

export default function Dashboard() {
  const wsUrl = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:8000/ws';
  const { data, connected, lastUpdate, error } = useWebSocketMonitor(wsUrl);
  const { alerts, connected: alertsConnected } = useWebSocketAlerts(wsUrl + '/alerts');

  const [vfdData, setVfdData] = useState<VFDData | null>(null);
  const [pzemData, setPzemData] = useState<PZEMData | null>(null);

  useEffect(() => {
    if (data) {
      setVfdData(data.vfd);
      setPzemData(data.pzem);
    }
  }, [data]);

  const getStatusVariant = (value: number, thresholds: { danger: number; warning: number }) => {
    if (value >= thresholds.danger) return 'danger';
    if (value >= thresholds.warning) return 'warning';
    return 'default';
  };

  const recentAlerts = alerts.slice(0, 3);
  const lastUpdateTime = lastUpdate
    ? new Date(lastUpdate).toLocaleTimeString()
    : 'Never';

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <h1 className="text-4xl font-bold text-text-primary">Predictive Maintenance Dashboard</h1>
        <div className="flex items-center justify-between">
          <p className="text-text-secondary">Real-time monitoring and control</p>
          <div className="flex items-center gap-4">
            <ConnectionStatus connected={connected} label="Monitor" />
            <ConnectionStatus connected={alertsConnected} label="Alerts" />
            <span className="text-xs text-text-secondary">Last Update: {lastUpdateTime}</span>
          </div>
        </div>
      </div>

      {error && (
        <div className="rounded-lg border border-accent-danger bg-accent-danger bg-opacity-10 p-4 text-accent-danger">
          {error}
        </div>
      )}

      {/* Status Overview */}
      {vfdData && (
        <div className="rounded-lg border border-border bg-surface-light p-6">
          <h2 className="mb-4 text-xl font-semibold text-text-primary">Motor Status</h2>
          <div className="flex items-center justify-between">
            <StatusIndicator status={vfdData.status} size="lg" />
            {vfdData.fault_code && (
              <div className="text-sm text-accent-danger">Fault Code: {vfdData.fault_code}</div>
            )}
          </div>
        </div>
      )}

      {/* VFD Monitoring */}
      {vfdData && (
        <div className="space-y-4">
          <h2 className="text-2xl font-semibold text-text-primary">VFD Monitoring</h2>
          <DataGrid cols={4} gap="md">
            <MonitorTile
              label="Motor Speed"
              value={vfdData.rpm}
              unit="RPM"
              variant={getStatusVariant(vfdData.rpm, { danger: 3600, warning: 3200 })}
              glowing
            />
            <MonitorTile
              label="Frequency"
              value={vfdData.frequency}
              unit="Hz"
              variant={getStatusVariant(vfdData.frequency, { danger: 60, warning: 55 })}
            />
            <MonitorTile
              label="Voltage"
              value={vfdData.voltage}
              unit="V"
              variant={getStatusVariant(vfdData.voltage, { danger: 250, warning: 200 })}
            />
            <MonitorTile
              label="Current"
              value={vfdData.current}
              unit="A"
              variant={getStatusVariant(vfdData.current, { danger: 20, warning: 15 })}
            />
            <MonitorTile
              label="Power"
              value={vfdData.power}
              unit="kW"
              variant={getStatusVariant(vfdData.power, { danger: 10, warning: 7.5 })}
              glowing
            />
            <MonitorTile
              label="Temperature"
              value={vfdData.temperature}
              unit="°C"
              variant={getStatusVariant(vfdData.temperature, { danger: 80, warning: 60 })}
            />
            <MonitorTile
              label="Phase R"
              value={vfdData.phase_r}
              unit="V"
              compact
            />
            <MonitorTile
              label="Phase Y"
              value={vfdData.phase_y}
              unit="V"
              compact
            />
            <MonitorTile
              label="Phase B"
              value={vfdData.phase_b}
              unit="V"
              compact
            />
          </DataGrid>
        </div>
      )}

      {/* PZEM Monitoring */}
      {pzemData && (
        <div className="space-y-4">
          <h2 className="text-2xl font-semibold text-text-primary">Power Quality (PZEM)</h2>
          <DataGrid cols={3} gap="md">
            <MonitorTile
              label="Voltage"
              value={pzemData.voltage}
              unit="V"
              variant={getStatusVariant(pzemData.voltage, { danger: 250, warning: 200 })}
              glowing
            />
            <MonitorTile
              label="Current"
              value={pzemData.current}
              unit="A"
              variant={getStatusVariant(pzemData.current, { danger: 30, warning: 20 })}
            />
            <MonitorTile
              label="Power"
              value={pzemData.power}
              unit="kW"
              variant={getStatusVariant(pzemData.power, { danger: 15, warning: 10 })}
              glowing
            />
            <MonitorTile
              label="Energy"
              value={pzemData.energy}
              unit="kWh"
            />
            <MonitorTile
              label="Frequency"
              value={pzemData.frequency}
              unit="Hz"
            />
            <MonitorTile
              label="Power Factor"
              value={pzemData.power_factor}
              unit=""
            />
          </DataGrid>
        </div>
      )}

      {/* Recent Alerts */}
      {recentAlerts.length > 0 && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-semibold text-text-primary">Recent Alerts</h2>
            <a href="/alerts" className="text-accent-primary hover:text-accent-primary/80 text-sm font-medium">
              View All →
            </a>
          </div>
          <div className="space-y-3">
            {recentAlerts.map((alert) => (
              <AlertCard key={alert.id} alert={alert} />
            ))}
          </div>
        </div>
      )}

      {!connected && (
        <div className="rounded-lg border border-accent-danger bg-accent-danger bg-opacity-10 p-4 text-accent-danger">
          Disconnected from monitoring system. Attempting to reconnect...
        </div>
      )}
    </div>
  );
}
