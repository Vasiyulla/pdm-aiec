'use client';

import React from 'react';
import clsx from 'clsx';

interface MonitorTileProps {
  label: string;
  value: number | string;
  unit?: string;
  variant?: 'default' | 'danger' | 'warning' | 'success';
  trend?: 'up' | 'down' | 'neutral';
  glowing?: boolean;
  compact?: boolean;
}

export function MonitorTile({
  label,
  value,
  unit = '',
  variant = 'default',
  trend,
  glowing = false,
  compact = false,
}: MonitorTileProps) {
  const variantClasses = {
    default: 'border-border bg-surface-light text-text-primary',
    danger: 'border-accent-danger bg-surface-light text-accent-danger',
    warning: 'border-accent-warning bg-surface-light text-accent-warning',
    success: 'border-accent-success bg-surface-light text-accent-success',
  };

  const glowClasses = {
    default: 'shadow-glow-cyan',
    danger: 'shadow-glow-danger',
    warning: 'shadow-glow-warning',
    success: 'shadow-glow-success',
  };

  return (
    <div
      className={clsx(
        'rounded-lg border p-4 transition-all duration-300',
        variantClasses[variant],
        glowing && glowClasses[variant],
        compact && 'p-3',
      )}
    >
      <div className={clsx('flex items-center justify-between', compact ? 'gap-2' : 'gap-3')}>
        <div className="flex-1">
          <p className={clsx('text-text-secondary', compact ? 'text-xs' : 'text-sm')}>{label}</p>
          <div className={clsx('flex items-baseline gap-1', compact ? 'mt-1' : 'mt-2')}>
            <span
              className={clsx(
                'font-mono font-bold tabular-nums',
                compact ? 'text-lg' : 'text-2xl',
              )}
            >
              {typeof value === 'number' ? value.toFixed(1) : value}
            </span>
            {unit && <span className={clsx('text-text-secondary', compact ? 'text-xs' : 'text-sm')}>{unit}</span>}
          </div>
        </div>

        {trend && (
          <div className={clsx('text-2xl', trend === 'up' ? 'text-accent-danger' : trend === 'down' ? 'text-accent-success' : 'text-text-secondary')}>
            {trend === 'up' ? '↑' : trend === 'down' ? '↓' : '→'}
          </div>
        )}
      </div>
    </div>
  );
}
