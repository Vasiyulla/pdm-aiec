'use client';

import React from 'react';
import clsx from 'clsx';

interface ConnectionStatusProps {
  connected: boolean;
  label?: string;
}

export function ConnectionStatus({
  connected,
  label = 'WebSocket',
}: ConnectionStatusProps) {
  return (
    <div className="flex items-center gap-2">
      <div
        className={clsx(
          'h-2 w-2 rounded-full',
          connected ? 'bg-accent-success animate-pulse' : 'bg-accent-danger',
        )}
      />
      <span className={clsx(
        'text-xs font-medium',
        connected ? 'text-accent-success' : 'text-accent-danger',
      )}>
        {connected ? `${label} Connected` : `${label} Disconnected`}
      </span>
    </div>
  );
}
