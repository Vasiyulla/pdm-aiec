'use client';

import { useEffect, useRef, useState } from 'react';
import { AlertData } from '../types';

interface UseWebSocketAlertsReturn {
  alerts: AlertData[];
  connected: boolean;
  error: string | null;
  acknowledgeAlert: (alertId: string) => void;
}

export function useWebSocketAlerts(wsUrl: string = 'ws://localhost:8000/ws/alerts'): UseWebSocketAlertsReturn {
  const [alerts, setAlerts] = useState<AlertData[]>([]);
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const wsRef = useRef<WebSocket | null>(null);
  const alertsRef = useRef<Map<string, AlertData>>(new Map());

  useEffect(() => {
    const ws = new WebSocket(wsUrl);

    ws.onopen = () => {
      setConnected(true);
      setError(null);
    };

    ws.onmessage = (event) => {
      try {
        const newAlert: AlertData = JSON.parse(event.data);
        
        // Add or update alert in map
        alertsRef.current.set(newAlert.id, newAlert);
        
        // Convert map to array and sort by timestamp (newest first)
        const alertArray = Array.from(alertsRef.current.values())
          .sort((a, b) => b.timestamp - a.timestamp);
        
        setAlerts(alertArray);
      } catch (err) {
        setError('Failed to parse alert data');
      }
    };

    ws.onerror = () => {
      setConnected(false);
      setError('WebSocket connection error');
    };

    ws.onclose = () => {
      setConnected(false);
    };

    wsRef.current = ws;

    return () => {
      ws.close();
    };
  }, [wsUrl]);

  const acknowledgeAlert = (alertId: string) => {
    const alert = alertsRef.current.get(alertId);
    if (alert) {
      alert.read = true;
      alertsRef.current.set(alertId, alert);
      setAlerts(Array.from(alertsRef.current.values()).sort((a, b) => b.timestamp - a.timestamp));

      // Send acknowledgment to server
      if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
        wsRef.current.send(JSON.stringify({ action: 'acknowledge', alert_id: alertId }));
      }
    }
  };

  return { alerts, connected, error, acknowledgeAlert };
}
