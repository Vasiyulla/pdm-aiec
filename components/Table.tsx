'use client';

import React from 'react';
import clsx from 'clsx';

interface Column<T> {
  key: string;
  label: string;
  render?: (value: any, item: T) => React.ReactNode;
  sortable?: boolean;
}

interface TableProps<T> {
  columns: Column<T>[];
  data: T[];
  rowKey: string;
  striped?: boolean;
  hoverable?: boolean;
  compact?: boolean;
}

export function Table<T extends Record<string, any>>({
  columns,
  data,
  rowKey,
  striped = true,
  hoverable = true,
  compact = false,
}: TableProps<T>) {
  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <table className="w-full text-left">
        <thead>
          <tr className="border-b border-border bg-surface">
            {columns.map((col) => (
              <th
                key={col.key}
                className={clsx(
                  'text-text-secondary font-semibold',
                  compact ? 'px-3 py-2 text-xs' : 'px-4 py-3 text-sm',
                )}
              >
                {col.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((item, index) => (
            <tr
              key={item[rowKey]}
              className={clsx(
                striped && index % 2 === 1 && 'bg-surface bg-opacity-50',
                hoverable && 'hover:bg-surface hover:bg-opacity-75 transition-colors',
              )}
            >
              {columns.map((col) => (
                <td
                  key={`${item[rowKey]}-${col.key}`}
                  className={clsx(
                    'text-text-primary',
                    compact ? 'px-3 py-2 text-xs' : 'px-4 py-3 text-sm',
                  )}
                >
                  {col.render ? col.render(item[col.key], item) : item[col.key]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      {data.length === 0 && (
        <div className="text-center py-8 text-text-secondary">
          No data available
        </div>
      )}
    </div>
  );
}
