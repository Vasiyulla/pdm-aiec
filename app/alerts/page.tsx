'use client';

import React, { useEffect, useState } from 'react';
import { useWebSocketAlerts } from '@/lib/hooks/useWebSocketAlerts';
import { AlertData } from '@/lib/types';
import { AlertCard } from '@/components/AlertCard';
import { ConnectionStatus } from '@/components/ConnectionStatus';
import { Table } from '@/components/Table';
import clsx from 'clsx';

export default function AlertsPage() {
  const wsUrl = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:8000/ws';
  const { alerts, connected, acknowledgeAlert } = useWebSocketAlerts(wsUrl + '/alerts');

  const [filterType, setFilterType] = useState<'all' | 'danger' | 'warning' | 'info'>('all');
  const [filterRead, setFilterRead] = useState<'all' | 'unread' | 'read'>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const filteredAlerts = alerts.filter((alert) => {
    if (filterType !== 'all' && alert.type !== filterType) return false;
    if (filterRead === 'unread' && alert.read) return false;
    if (filterRead === 'read' && !alert.read) return false;
    if (searchQuery && !alert.title.toLowerCase().includes(searchQuery.toLowerCase()) &&
        !alert.message.toLowerCase().includes(searchQuery.toLowerCase())) {
      return false;
    }
    return true;
  });

  const unreadCount = alerts.filter((a) => !a.read).length;
  const dangerCount = alerts.filter((a) => a.type === 'danger').length;
  const warningCount = alerts.filter((a) => a.type === 'warning').length;

  const typeConfig = {
    danger: { color: 'text-accent-danger', bgColor: 'bg-accent-danger/10', badge: '🔴' },
    warning: { color: 'text-accent-warning', bgColor: 'bg-accent-warning/10', badge: '🟡' },
    info: { color: 'text-accent-primary', bgColor: 'bg-accent-primary/10', badge: '🔵' },
  };

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <h1 className="text-4xl font-bold text-text-primary">Alerts & Logs</h1>
        <div className="flex items-center justify-between">
          <p className="text-text-secondary">Monitor system alerts and event logs</p>
          <ConnectionStatus connected={connected} label="Alerts" />
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="rounded-lg border border-border bg-surface-light p-4">
          <p className="text-sm text-text-secondary">Total Alerts</p>
          <p className="text-2xl font-bold text-text-primary mt-2">{alerts.length}</p>
        </div>
        <div className="rounded-lg border border-accent-danger bg-accent-danger bg-opacity-10 p-4">
          <p className="text-sm text-accent-danger">Critical</p>
          <p className="text-2xl font-bold text-accent-danger mt-2">{dangerCount}</p>
        </div>
        <div className="rounded-lg border border-accent-warning bg-accent-warning bg-opacity-10 p-4">
          <p className="text-sm text-accent-warning">Warnings</p>
          <p className="text-2xl font-bold text-accent-warning mt-2">{warningCount}</p>
        </div>
        <div className="rounded-lg border border-accent-primary bg-accent-primary bg-opacity-10 p-4">
          <p className="text-sm text-accent-primary">Unread</p>
          <p className="text-2xl font-bold text-accent-primary mt-2">{unreadCount}</p>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="space-y-4">
        <div className="flex flex-col lg:flex-row gap-4">
          {/* Search */}
          <div className="flex-1">
            <input
              type="text"
              placeholder="Search alerts..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full px-4 py-2 rounded-lg border border-border bg-surface text-text-primary placeholder-text-secondary focus:outline-none focus:border-accent-primary transition-colors"
            />
          </div>

          {/* Type Filter */}
          <div className="flex gap-2">
            {(['all', 'danger', 'warning', 'info'] as const).map((type) => (
              <button
                key={type}
                onClick={() => setFilterType(type)}
                className={clsx(
                  'px-4 py-2 rounded-lg font-medium text-sm transition-colors capitalize',
                  filterType === type
                    ? type === 'all'
                      ? 'bg-accent-primary text-background'
                      : `${typeConfig[type as 'danger' | 'warning' | 'info'].bgColor} ${typeConfig[type as 'danger' | 'warning' | 'info'].color}`
                    : 'bg-surface border border-border text-text-secondary hover:border-text-secondary',
                )}
              >
                {type}
              </button>
            ))}
          </div>

          {/* Read Filter */}
          <div className="flex gap-2">
            {(['all', 'unread', 'read'] as const).map((read) => (
              <button
                key={read}
                onClick={() => setFilterRead(read)}
                className={clsx(
                  'px-4 py-2 rounded-lg font-medium text-sm transition-colors capitalize',
                  filterRead === read
                    ? 'bg-accent-primary text-background'
                    : 'bg-surface border border-border text-text-secondary hover:border-text-secondary',
                )}
              >
                {read}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Alerts List */}
      <div className="space-y-4">
        {filteredAlerts.length > 0 ? (
          <div className="space-y-3">
            {filteredAlerts.map((alert) => (
              <div key={alert.id} className="group relative">
                <AlertCard
                  alert={alert}
                  onDismiss={() => acknowledgeAlert(alert.id)}
                />
                {!alert.read && (
                  <div className="absolute top-4 right-4 h-3 w-3 rounded-full bg-accent-primary" />
                )}
              </div>
            ))}
          </div>
        ) : (
          <div className="rounded-lg border border-border bg-surface-light p-8 text-center">
            <p className="text-text-secondary">No alerts match your filters</p>
          </div>
        )}
      </div>

      {/* Alert History Table */}
      {alerts.length > 0 && (
        <div className="space-y-4">
          <h2 className="text-2xl font-semibold text-text-primary">Alert History</h2>
          <Table
            data={alerts.slice(0, 20)}
            rowKey="id"
            columns={[
              {
                key: 'type',
                label: 'Type',
                render: (value) => (
                  <span className={clsx('font-semibold', typeConfig[value as 'danger' | 'warning' | 'info'].color)}>
                    {typeConfig[value as 'danger' | 'warning' | 'info'].badge}
                  </span>
                ),
              },
              {
                key: 'title',
                label: 'Title',
                render: (value) => <span className="font-medium">{value}</span>,
              },
              {
                key: 'message',
                label: 'Message',
                render: (value) => <span className="text-text-secondary">{value}</span>,
              },
              {
                key: 'timestamp',
                label: 'Time',
                render: (value) => new Date(value).toLocaleTimeString(),
              },
              {
                key: 'source',
                label: 'Source',
              },
              {
                key: 'read',
                label: 'Status',
                render: (value) => (
                  <span className={clsx('text-sm font-medium', value ? 'text-text-secondary' : 'text-accent-primary')}>
                    {value ? 'Read' : 'Unread'}
                  </span>
                ),
              },
            ]}
          />
        </div>
      )}
    </div>
  );
}
