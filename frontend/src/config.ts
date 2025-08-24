// Centralized configuration for API URLs
import { Platform } from 'react-native';

const ENV = process.env.NODE_ENV === 'production' ? 'production' : 'development'; // Use production in prod builds

// For iOS simulator, localhost won't work. Use your computer's local IP instead
// For Android emulator, use 10.0.2.2 to reference your computer's localhost
const LOCAL_IP = Platform.select({
  ios: '10.0.0.59',
  android: '10.0.2.2',
  default: 'localhost',
});

// Try to import from process.env first, then fallback to hardcoded values
const getApiBaseUrl = () => {
  // Check for environment variable from .env file
  if (process.env.REACT_APP_API_BASE_URL) {
    return process.env.REACT_APP_API_BASE_URL;
  }

  // Otherwise use platform-specific fallbacks
  return Platform.OS === 'web' 
    ? 'http://localhost:8000' 
    : `http://${LOCAL_IP}:8000`;
};

const CONFIG = {
  development: {
    API_BASE_URL: getApiBaseUrl(),
    ENABLE_API_LOGS: false, // Disable API logging by default
  },
  production: {
    API_BASE_URL: 'https://glucopilot-8ed6389c53c8.herokuapp.com/', // Heroku production URL
    ENABLE_API_LOGS: false,
  },
};

export const API_BASE_URL = CONFIG[ENV].API_BASE_URL;
export const ENABLE_API_LOGS = CONFIG[ENV].ENABLE_API_LOGS;

// For debugging
console.log(`API configured to connect to: ${API_BASE_URL}`);
