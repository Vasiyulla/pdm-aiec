'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { MonitorData, VFDData, PZEMData } from '../types';

interface UseWebSocketMonitorReturn {
  data: MonitorData | null;
  connected: boolean;
  lastUpdate: number;
  error: string | null;
}

export function useWebSocketMonitor(wsUrl: string = 'ws://localhost:8000/ws'): UseWebSocketMonitorReturn {
  const [data, setData] = useState<MonitorData | null>(null);
  const [connected, setConnected] = useState(false);
  const [lastUpdate, setLastUpdate] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const wsRef = useRef<WebSocket | null>(null);
  const animationFrameRef = useRef<number | null>(null);
  const pendingDataRef = useRef<MonitorData | null>(null);
  const lastRenderTimeRef = useRef<number>(0);

  const throttleInterval = 1000 / 30; // 30 FPS throttling

  const processData = useCallback((newData: MonitorData) => {
    pendingDataRef.current = newData;

    if (animationFrameRef.current === null) {
      animationFrameRef.current = requestAnimationFrame(() => {
        const now = performance.now();

        // Check if enough time has passed since last render (30 FPS = ~33ms)
        if (now - lastRenderTimeRef.current >= throttleInterval) {
          if (pendingDataRef.current) {
            setData(pendingDataRef.current);
            setLastUpdate(Date.now());
            lastRenderTimeRef.current = now;
          }
        }

        animationFrameRef.current = null;

        // Schedule another check if more data is pending
        if (pendingDataRef.current) {
          const nextFrameTime = lastRenderTimeRef.current + throttleInterval - (now - lastRenderTimeRef.current);
          if (nextFrameTime > 0) {
            animationFrameRef.current = requestAnimationFrame(() => processData(pendingDataRef.current!));
          } else {
            processData(pendingDataRef.current);
          }
        }
      });
    }
  }, [throttleInterval]);

  useEffect(() => {
    const ws = new WebSocket(wsUrl);

    ws.onopen = () => {
      setConnected(true);
      setError(null);
    };

    ws.onmessage = (event) => {
      try {
        const newData: MonitorData = JSON.parse(event.data);
        processData(newData);
      } catch (err) {
        setError('Failed to parse WebSocket data');
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
      if (animationFrameRef.current !== null) {
        cancelAnimationFrame(animationFrameRef.current);
      }
      ws.close();
    };
  }, [wsUrl, processData]);

  return { data, connected, lastUpdate, error };
}
