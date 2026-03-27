/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './app/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        background: '#0f1419',
        surface: '#1a2332',
        'surface-light': '#232f3f',
        border: '#3a4a5c',
        'text-primary': '#e8eef5',
        'text-secondary': '#a0aabb',
        'accent-primary': '#00d9ff',
        'accent-danger': '#ff4757',
        'accent-warning': '#ffa502',
        'accent-success': '#2ed573',
      },
      boxShadow: {
        'glow-cyan': '0 0 20px rgba(0, 217, 255, 0.3)',
        'glow-danger': '0 0 20px rgba(255, 71, 87, 0.3)',
        'glow-warning': '0 0 20px rgba(255, 165, 2, 0.3)',
        'glow-success': '0 0 20px rgba(46, 213, 115, 0.3)',
      },
      keyframes: {
        pulse: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.7' },
        },
        glow: {
          '0%, 100%': { 'box-shadow': '0 0 10px rgba(0, 217, 255, 0.3)' },
          '50%': { 'box-shadow': '0 0 20px rgba(0, 217, 255, 0.6)' },
        },
      },
      animation: {
        pulse: 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        glow: 'glow 2s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};
