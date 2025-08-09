// Centralized configuration for API URLs
import { Platform } from 'react-native';

const ENV = 'development'; // Force development environment for local dev

// For iOS simulator, localhost won't work. Use your computer's local IP instead
// For Android emulator, use 10.0.2.2 to reference your computer's localhost
const LOCAL_IP = Platform.select({
  ios: '10.0.0.2', // Replace with your actual local IP address
  android: '10.0.2.2',
  default: 'localhost',
});

const CONFIG = {
  development: {
    // Use your computer's IP when running on a real device or simulator
    API_BASE_URL: Platform.OS === 'web' 
      ? 'http://localhost:8000' 
      : `http://${LOCAL_IP}:8000`,
    ENABLE_API_LOGS: true, // Enable API logging for debugging
  },
  production: {
    API_BASE_URL: 'https://api.glucopilot.com', // Updated production URL
    ENABLE_API_LOGS: false,
  },
};

export const API_BASE_URL = CONFIG[ENV].API_BASE_URL;
export const ENABLE_API_LOGS = CONFIG[ENV].ENABLE_API_LOGS;
