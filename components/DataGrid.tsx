'use client';

import React from 'react';
import clsx from 'clsx';

interface GridProps {
  children: React.ReactNode;
  cols?: number;
  gap?: 'sm' | 'md' | 'lg';
}

const gapMap = {
  sm: 'gap-3',
  md: 'gap-4',
  lg: 'gap-6',
};

export function DataGrid({
  children,
  cols = 4,
  gap = 'md',
}: GridProps) {
  return (
    <div
      className={clsx(
        'grid',
        {
          'grid-cols-1': cols === 1,
          'grid-cols-2': cols === 2,
          'grid-cols-3': cols === 3,
          'grid-cols-4': cols === 4,
          'sm:grid-cols-1 md:grid-cols-2 lg:grid-cols-4': cols === 'auto',
        },
        gapMap[gap],
      )}
    >
      {children}
    </div>
  );
}
