'use client';

import React, { useEffect, useState } from 'react';
import { useWebSocketMonitor } from '@/lib/hooks/useWebSocketMonitor';
import { MotorControls } from '@/components/MotorControls';
import { MonitorTile } from '@/components/MonitorTile';
import { StatusIndicator } from '@/components/StatusIndicator';
import { ConnectionStatus } from '@/components/ConnectionStatus';
import { DataGrid } from '@/components/DataGrid';

export default function ControlPage() {
  const wsUrl = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:8000/ws';
  const { data, connected } = useWebSocketMonitor(wsUrl);

  const [motorRunning, setMotorRunning] = useState(false);
  const [speedSetpoint, setSpeedSetpoint] = useState(0);

  useEffect(() => {
    if (data) {
      setMotorRunning(data.vfd.status === 'running');
      setSpeedSetpoint(data.vfd.rpm);
    }
  }, [data]);

  const vfdData = data?.vfd;

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <h1 className="text-4xl font-bold text-text-primary">Control Center</h1>
        <div className="flex items-center justify-between">
          <p className="text-text-secondary">Motor and system control interface</p>
          <ConnectionStatus connected={connected} label="Monitor" />
        </div>
      </div>

      {/* Motor Status Overview */}
      {vfdData && (
        <div className="rounded-lg border border-border bg-surface-light p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-semibold text-text-primary">Motor Status</h2>
            <StatusIndicator status={vfdData.status} size="lg" />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <MonitorTile
              label="Current Speed"
              value={vfdData.rpm}
              unit="RPM"
              variant={vfdData.status === 'running' ? 'success' : 'warning'}
              glowing
            />
            <MonitorTile
              label="Current"
              value={vfdData.current}
              unit="A"
              variant={vfdData.current > 15 ? 'warning' : 'default'}
            />
            <MonitorTile
              label="Temperature"
              value={vfdData.temperature}
              unit="°C"
              variant={vfdData.temperature > 60 ? 'warning' : 'default'}
            />
          </div>
        </div>
      )}

      {/* Control Panels */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Motor Controls */}
        <div className="lg:col-span-2">
          {vfdData && (
            <MotorControls
              motorId="motor-1"
              motorRunning={motorRunning}
              currentSpeed={speedSetpoint}
              onStateChange={setMotorRunning}
            />
          )}
        </div>

        {/* Safety Info */}
        <div className="rounded-lg border border-accent-warning bg-accent-warning bg-opacity-10 p-6 space-y-4 h-fit">
          <h3 className="text-lg font-semibold text-accent-warning">Safety Guidelines</h3>
          <ul className="space-y-2 text-sm text-text-secondary">
            <li className="flex gap-2">
              <span className="text-accent-warning">•</span>
              <span>Ensure area is clear before starting</span>
            </li>
            <li className="flex gap-2">
              <span className="text-accent-warning">•</span>
              <span>Monitor temperature during operation</span>
            </li>
            <li className="flex gap-2">
              <span className="text-accent-warning">•</span>
              <span>Stop immediately if unusual sounds</span>
            </li>
            <li className="flex gap-2">
              <span className="text-accent-warning">•</span>
              <span>Never exceed speed limits</span>
            </li>
            <li className="flex gap-2">
              <span className="text-accent-warning">•</span>
              <span>Check power factor regularly</span>
            </li>
          </ul>
        </div>
      </div>

      {/* Detailed Monitoring */}
      {vfdData && (
        <div className="space-y-4">
          <h2 className="text-2xl font-semibold text-text-primary">Detailed Parameters</h2>
          <DataGrid cols={3} gap="md">
            <MonitorTile
              label="Frequency"
              value={vfdData.frequency}
              unit="Hz"
            />
            <MonitorTile
              label="Voltage"
              value={vfdData.voltage}
              unit="V"
            />
            <MonitorTile
              label="Power"
              value={vfdData.power}
              unit="kW"
              glowing
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

      {/* Emergency Stop Section */}
      <div className="rounded-lg border-2 border-accent-danger bg-accent-danger bg-opacity-5 p-6">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold text-accent-danger">Emergency Stop</h3>
            <p className="text-sm text-text-secondary mt-1">
              Use this in case of emergency or hazardous conditions
            </p>
          </div>
          <button
            className="px-8 py-3 rounded-lg bg-accent-danger text-white font-semibold hover:bg-accent-danger/90 transition-colors animate-pulse"
            onClick={() => {
              // Trigger emergency stop
              alert('Emergency stop triggered!');
            }}
          >
            EMERGENCY STOP
          </button>
        </div>
      </div>

      {!connected && (
        <div className="rounded-lg border border-accent-danger bg-accent-danger bg-opacity-10 p-4 text-accent-danger">
          System disconnected. Control functions unavailable.
        </div>
      )}
    </div>
  );
}
