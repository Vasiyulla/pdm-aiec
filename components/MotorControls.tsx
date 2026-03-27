'use client';

import React, { useState } from 'react';
import { startMotor, stopMotor, setSpeed } from '@/lib/api';
import clsx from 'clsx';

interface MotorControlsProps {
  motorId: string;
  motorRunning: boolean;
  currentSpeed: number;
  onStateChange?: (running: boolean) => void;
}

export function MotorControls({
  motorId,
  motorRunning,
  currentSpeed,
  onStateChange,
}: MotorControlsProps) {
  const [loading, setLoading] = useState(false);
  const [speedInput, setSpeedInput] = useState(currentSpeed.toString());

  const handleStart = async () => {
    setLoading(true);
    try {
      await startMotor(motorId);
      onStateChange?.(true);
    } catch (error) {
      console.error('Failed to start motor:', error);
    }
    setLoading(false);
  };

  const handleStop = async () => {
    setLoading(true);
    try {
      await stopMotor(motorId);
      onStateChange?.(false);
    } catch (error) {
      console.error('Failed to stop motor:', error);
    }
    setLoading(false);
  };

  const handleSetSpeed = async () => {
    setLoading(true);
    try {
      const speed = parseFloat(speedInput);
      if (speed >= 0 && speed <= 100) {
        await setSpeed(motorId, speed);
      }
    } catch (error) {
      console.error('Failed to set speed:', error);
    }
    setLoading(false);
  };

  return (
    <div className="space-y-4 rounded-lg border border-border bg-surface-light p-6">
      <h3 className="text-lg font-semibold text-text-primary">Motor Controls</h3>

      <div className="space-y-3">
        {/* Start/Stop Buttons */}
        <div className="grid grid-cols-2 gap-3">
          <button
            onClick={handleStart}
            disabled={loading || motorRunning}
            className={clsx(
              'rounded-lg py-2 font-medium transition-all duration-200',
              motorRunning
                ? 'bg-surface border border-border text-text-secondary cursor-not-allowed'
                : 'border border-accent-success bg-accent-success bg-opacity-20 text-accent-success hover:bg-opacity-30',
            )}
          >
            {loading ? 'Starting...' : 'Start'}
          </button>
          <button
            onClick={handleStop}
            disabled={loading || !motorRunning}
            className={clsx(
              'rounded-lg py-2 font-medium transition-all duration-200',
              !motorRunning
                ? 'bg-surface border border-border text-text-secondary cursor-not-allowed'
                : 'border border-accent-danger bg-accent-danger bg-opacity-20 text-accent-danger hover:bg-opacity-30',
            )}
          >
            {loading ? 'Stopping...' : 'Stop'}
          </button>
        </div>

        {/* Speed Control */}
        <div className="space-y-2">
          <label className="block text-sm text-text-secondary">Speed (%)</label>
          <div className="flex gap-2">
            <input
              type="range"
              min="0"
              max="100"
              value={speedInput}
              onChange={(e) => setSpeedInput(e.target.value)}
              className="flex-1"
            />
            <input
              type="number"
              min="0"
              max="100"
              value={speedInput}
              onChange={(e) => setSpeedInput(e.target.value)}
              className="w-16 rounded-lg border border-border bg-surface px-2 py-1 text-center text-text-primary"
            />
          </div>
        </div>

        <button
          onClick={handleSetSpeed}
          disabled={loading}
          className="w-full rounded-lg border border-accent-primary bg-accent-primary bg-opacity-20 py-2 font-medium text-accent-primary transition-all duration-200 hover:bg-opacity-30"
        >
          {loading ? 'Setting...' : 'Set Speed'}
        </button>
      </div>
    </div>
  );
}
