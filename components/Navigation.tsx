'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import clsx from 'clsx';

const navItems = [
  { href: '/', label: 'Dashboard' },
  { href: '/control', label: 'Control' },
  { href: '/alerts', label: 'Alerts & Logs' },
  { href: '/analytics', label: 'Analytics' },
];

export function Navigation() {
  const pathname = usePathname();

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 border-b border-border bg-surface backdrop-blur-md">
      <div className="mx-auto max-w-7xl px-4">
        <div className="flex items-center justify-between h-20">
          <div className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-accent-primary to-accent-success" />
            <span className="text-xl font-bold text-text-primary">PdM-AIEC</span>
          </div>

          <div className="flex items-center gap-8">
            {navItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className={clsx(
                  'text-sm font-medium transition-colors duration-200',
                  pathname === item.href
                    ? 'text-accent-primary'
                    : 'text-text-secondary hover:text-text-primary',
                )}
              >
                {item.label}
              </Link>
            ))}
          </div>
        </div>
      </div>
    </nav>
  );
}
