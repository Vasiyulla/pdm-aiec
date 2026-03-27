'use client';

import React from 'react';
import clsx from 'clsx';

interface StatusIndicatorProps {
  status: 'running' | 'stopped' | 'fault' | 'warning' | 'healthy';
  label?: string;
  size?: 'sm' | 'md' | 'lg';
  animated?: boolean;
}

export function StatusIndicator({
  status,
  label,
  size = 'md',
  animated = true,
}: StatusIndicatorProps) {
  const statusConfig = {
    running: { color: 'bg-accent-success', glow: 'shadow-glow-success', text: 'Running' },
    stopped: { color: 'bg-accent-warning', glow: 'shadow-glow-warning', text: 'Stopped' },
    fault: { color: 'bg-accent-danger', glow: 'shadow-glow-danger', text: 'Fault' },
    warning: { color: 'bg-accent-warning', glow: 'shadow-glow-warning', text: 'Warning' },
    healthy: { color: 'bg-accent-success', glow: 'shadow-glow-success', text: 'Healthy' },
  };

  const sizeClasses = {
    sm: 'h-3 w-3',
    md: 'h-4 w-4',
    lg: 'h-6 w-6',
  };

  const config = statusConfig[status];

  return (
    <div className="flex items-center gap-2">
      <div
        className={clsx(
          'rounded-full',
          sizeClasses[size],
          config.color,
          config.glow,
          animated && 'animate-pulse',
        )}
      />
      <span className="text-sm text-text-secondary">{label || config.text}</span>
    </div>
  );
}
