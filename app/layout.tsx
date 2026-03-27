import type { Metadata } from 'next';
import './globals.css';
import { Navigation } from '@/components/Navigation';

export const metadata: Metadata = {
  title: 'PdM-AIEC Dashboard',
  description: 'Predictive Maintenance & AI-Enabled Control Dashboard',
  viewport: {
    width: 'device-width',
    initialScale: 1,
    maximumScale: 1,
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-background text-text-primary">
        <Navigation />
        <main className="min-h-screen pt-20">{children}</main>
      </body>
    </html>
  );
}
