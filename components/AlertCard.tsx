'use client';

import React from 'react';
import { AlertData } from '@/lib/types';
import clsx from 'clsx';

interface AlertCardProps {
  alert: AlertData;
  onDismiss?: () => void;
  compact?: boolean;
}

export function AlertCard({ alert, onDismiss, compact = false }: AlertCardProps) {
  const typeConfig = {
    danger: { color: 'border-accent-danger bg-accent-danger bg-opacity-10 text-accent-danger', icon: '⚠️' },
    warning: { color: 'border-accent-warning bg-accent-warning bg-opacity-10 text-accent-warning', icon: '⚡' },
    info: { color: 'border-accent-primary bg-accent-primary bg-opacity-10 text-accent-primary', icon: 'ℹ️' },
  };

  const config = typeConfig[alert.type];
  const time = new Date(alert.timestamp).toLocaleTimeString();

  return (
    <div className={clsx('rounded-lg border', config.color, compact ? 'p-3' : 'p-4')}>
      <div className="flex items-start gap-3">
        <span className={clsx('text-xl', compact && 'text-lg')}>{config.icon}</span>
        <div className="flex-1">
          <p className={clsx('font-semibold text-text-primary', compact && 'text-sm')}>
            {alert.title}
          </p>
          <p className={clsx('mt-1 text-text-secondary', compact ? 'text-xs' : 'text-sm')}>
            {alert.message}
          </p>
          <p className="mt-2 text-xs text-text-secondary opacity-75">
            {time} • {alert.source}
          </p>
        </div>
        {onDismiss && (
          <button
            onClick={onDismiss}
            className="text-text-secondary hover:text-text-primary transition-colors"
          >
            ✕
          </button>
        )}
      </div>
    </div>
  );
}
