'use client';

import React, { useEffect, useState } from 'react';
import { getAnalytics } from '@/lib/api';
import { AnalyticsData } from '@/lib/types';
import { RPMChart, PowerChart, CurrentChart } from '@/components/Charts';
import { MonitorTile } from '@/components/MonitorTile';
import { DataGrid } from '@/components/DataGrid';
import { useWebSocketMonitor } from '@/lib/hooks/useWebSocketMonitor';

export default function AnalyticsPage() {
  const wsUrl = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:8000/ws';
  const { data: currentData, connected } = useWebSocketMonitor(wsUrl);

  const [analyticsData, setAnalyticsData] = useState<AnalyticsData[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<'1h' | '4h' | '24h' | '7d'>('1h');

  useEffect(() => {
    const loadAnalytics = async () => {
      setLoading(true);
      try {
        const now = Date.now();
        const ranges = {
          '1h': 60 * 60 * 1000,
          '4h': 4 * 60 * 60 * 1000,
          '24h': 24 * 60 * 60 * 1000,
          '7d': 7 * 24 * 60 * 60 * 1000,
        };

        const startTime = Math.floor((now - ranges[timeRange]) / 1000);
        const endTime = Math.floor(now / 1000);

        const data = await getAnalytics(startTime, endTime);
        setAnalyticsData(data);
      } catch (error) {
        console.error('Failed to load analytics:', error);
      }
      setLoading(false);
    };

    loadAnalytics();
  }, [timeRange]);

  // Calculate statistics
  const stats = analyticsData.length > 0 ? {
    avgRpm: Math.round(analyticsData.reduce((sum, d) => sum + d.rpm, 0) / analyticsData.length),
    maxRpm: Math.max(...analyticsData.map((d) => d.rpm)),
    minRpm: Math.min(...analyticsData.map((d) => d.rpm)),
    avgPower: (analyticsData.reduce((sum, d) => sum + d.power, 0) / analyticsData.length).toFixed(2),
    maxPower: Math.max(...analyticsData.map((d) => d.power)).toFixed(2),
    avgCurrent: (analyticsData.reduce((sum, d) => sum + d.current, 0) / analyticsData.length).toFixed(2),
    maxCurrent: Math.max(...analyticsData.map((d) => d.current)).toFixed(2),
    avgTemp: Math.round(analyticsData.reduce((sum, d) => sum + d.temperature, 0) / analyticsData.length),
    maxTemp: Math.max(...analyticsData.map((d) => d.temperature)),
    avgEfficiency: (analyticsData.reduce((sum, d) => sum + d.efficiency, 0) / analyticsData.length).toFixed(2),
  } : null;

  const formattedData = analyticsData.map((d) => ({
    ...d,
    timestamp: new Date(d.timestamp * 1000).toLocaleTimeString(),
  }));

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <h1 className="text-4xl font-bold text-text-primary">Analytics & Reporting</h1>
        <p className="text-text-secondary">Historical data and performance metrics</p>
      </div>

      {/* Time Range Selector */}
      <div className="flex gap-3">
        {(['1h', '4h', '24h', '7d'] as const).map((range) => (
          <button
            key={range}
            onClick={() => setTimeRange(range)}
            className={`px-4 py-2 rounded-lg font-medium text-sm transition-colors ${
              timeRange === range
                ? 'bg-accent-primary text-background'
                : 'bg-surface border border-border text-text-secondary hover:border-text-secondary'
            }`}
          >
            {range === '1h' ? '1 Hour' : range === '4h' ? '4 Hours' : range === '24h' ? '24 Hours' : '7 Days'}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="text-center py-12">
          <p className="text-text-secondary">Loading analytics...</p>
        </div>
      ) : (
        <>
          {/* Summary Statistics */}
          {stats && (
            <div className="space-y-4">
              <h2 className="text-2xl font-semibold text-text-primary">Summary Statistics</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="rounded-lg border border-border bg-surface-light p-4">
                  <p className="text-sm text-text-secondary">Avg Speed</p>
                  <p className="text-2xl font-bold text-accent-primary mt-2">{stats.avgRpm} RPM</p>
                  <p className="text-xs text-text-secondary mt-1">Min: {stats.minRpm} Max: {stats.maxRpm}</p>
                </div>
                <div className="rounded-lg border border-border bg-surface-light p-4">
                  <p className="text-sm text-text-secondary">Avg Power</p>
                  <p className="text-2xl font-bold text-accent-primary mt-2">{stats.avgPower} kW</p>
                  <p className="text-xs text-text-secondary mt-1">Peak: {stats.maxPower} kW</p>
                </div>
                <div className="rounded-lg border border-border bg-surface-light p-4">
                  <p className="text-sm text-text-secondary">Avg Current</p>
                  <p className="text-2xl font-bold text-accent-primary mt-2">{stats.avgCurrent} A</p>
                  <p className="text-xs text-text-secondary mt-1">Peak: {stats.maxCurrent} A</p>
                </div>
                <div className="rounded-lg border border-border bg-surface-light p-4">
                  <p className="text-sm text-text-secondary">Efficiency</p>
                  <p className="text-2xl font-bold text-accent-success mt-2">{stats.avgEfficiency}%</p>
                  <p className="text-xs text-text-secondary mt-1">Temp: {stats.avgTemp}°C</p>
                </div>
              </div>
            </div>
          )}

          {/* Charts */}
          <div className="space-y-6">
            <h2 className="text-2xl font-semibold text-text-primary">Performance Charts</h2>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <RPMChart data={formattedData} title="Motor Speed (RPM)" />
              <PowerChart data={formattedData} title="Power Consumption (kW)" />
            </div>

            <CurrentChart data={formattedData} title="Current Draw (A)" />
          </div>

          {/* Detailed Table */}
          {analyticsData.length > 0 && (
            <div className="space-y-4">
              <h2 className="text-2xl font-semibold text-text-primary">Detailed Records</h2>
              <div className="overflow-x-auto rounded-lg border border-border">
                <table className="w-full text-left text-sm">
                  <thead>
                    <tr className="border-b border-border bg-surface">
                      <th className="px-4 py-3 text-text-secondary font-semibold">Time</th>
                      <th className="px-4 py-3 text-text-secondary font-semibold">Speed (RPM)</th>
                      <th className="px-4 py-3 text-text-secondary font-semibold">Power (kW)</th>
                      <th className="px-4 py-3 text-text-secondary font-semibold">Current (A)</th>
                      <th className="px-4 py-3 text-text-secondary font-semibold">Temp (°C)</th>
                      <th className="px-4 py-3 text-text-secondary font-semibold">Efficiency (%)</th>
                    </tr>
                  </thead>
                  <tbody>
                    {formattedData.slice(0, 50).map((record, idx) => (
                      <tr key={idx} className="border-b border-border hover:bg-surface/50 transition-colors">
                        <td className="px-4 py-3 text-text-primary">{record.timestamp}</td>
                        <td className="px-4 py-3 text-text-primary font-mono">{record.rpm.toFixed(1)}</td>
                        <td className="px-4 py-3 text-text-primary font-mono">{record.power.toFixed(2)}</td>
                        <td className="px-4 py-3 text-text-primary font-mono">{record.current.toFixed(2)}</td>
                        <td className="px-4 py-3 text-text-primary font-mono">{record.temperature.toFixed(1)}</td>
                        <td className="px-4 py-3 text-text-primary font-mono">{record.efficiency.toFixed(1)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p className="text-xs text-text-secondary">
                Showing {Math.min(50, analyticsData.length)} of {analyticsData.length} records
              </p>
            </div>
          )}

          {/* Recommendations */}
          {stats && (
            <div className="rounded-lg border border-accent-success bg-accent-success bg-opacity-10 p-6 space-y-4">
              <h3 className="text-lg font-semibold text-accent-success">Performance Insights</h3>
              <ul className="space-y-2 text-sm text-text-secondary">
                <li className="flex gap-2">
                  <span className="text-accent-success">✓</span>
                  <span>Average efficiency: {stats.avgEfficiency}% is within optimal range</span>
                </li>
                <li className="flex gap-2">
                  <span className="text-accent-success">✓</span>
                  <span>Peak temperature: {stats.maxTemp}°C - monitor for excessive heat</span>
                </li>
                <li className="flex gap-2">
                  <span className="text-accent-success">✓</span>
                  <span>Current stability: Average {stats.avgCurrent}A with peak {stats.maxCurrent}A</span>
                </li>
              </ul>
            </div>
          )}
        </>
      )}
    </div>
  );
}
