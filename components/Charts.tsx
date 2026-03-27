'use client';

import React from 'react';
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';

interface ChartProps {
  data: any[];
  title: string;
  height?: number;
}

export function RPMChart({ data, title }: ChartProps) {
  return (
    <div className="rounded-lg border border-border bg-surface-light p-6">
      <h3 className="mb-4 text-lg font-semibold text-text-primary">{title}</h3>
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#3a4a5c" />
          <XAxis dataKey="timestamp" stroke="#a0aabb" />
          <YAxis stroke="#a0aabb" />
          <Tooltip
            contentStyle={{
              backgroundColor: '#1a2332',
              border: '1px solid #3a4a5c',
              borderRadius: '8px',
            }}
          />
          <Legend />
          <Line
            type="monotone"
            dataKey="rpm"
            stroke="#00d9ff"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

export function PowerChart({ data, title }: ChartProps) {
  return (
    <div className="rounded-lg border border-border bg-surface-light p-6">
      <h3 className="mb-4 text-lg font-semibold text-text-primary">{title}</h3>
      <ResponsiveContainer width="100%" height={300}>
        <AreaChart data={data}>
          <defs>
            <linearGradient id="colorPower" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#00d9ff" stopOpacity={0.3} />
              <stop offset="95%" stopColor="#00d9ff" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#3a4a5c" />
          <XAxis dataKey="timestamp" stroke="#a0aabb" />
          <YAxis stroke="#a0aabb" />
          <Tooltip
            contentStyle={{
              backgroundColor: '#1a2332',
              border: '1px solid #3a4a5c',
              borderRadius: '8px',
            }}
          />
          <Legend />
          <Area
            type="monotone"
            dataKey="power"
            stroke="#00d9ff"
            fillOpacity={1}
            fill="url(#colorPower)"
            isAnimationActive={false}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

export function CurrentChart({ data, title }: ChartProps) {
  return (
    <div className="rounded-lg border border-border bg-surface-light p-6">
      <h3 className="mb-4 text-lg font-semibold text-text-primary">{title}</h3>
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#3a4a5c" />
          <XAxis dataKey="timestamp" stroke="#a0aabb" />
          <YAxis stroke="#a0aabb" />
          <Tooltip
            contentStyle={{
              backgroundColor: '#1a2332',
              border: '1px solid #3a4a5c',
              borderRadius: '8px',
            }}
          />
          <Legend />
          <Line
            type="monotone"
            dataKey="current"
            stroke="#ffa502"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
