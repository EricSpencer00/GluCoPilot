// Centralized configuration for API URLs
import { Platform } from 'react-native';
import Config from 'react-native-config';

const ENV = __DEV__ ? 'development' : 'production';

// For iOS simulator, localhost won't work. Use your computer's local IP instead
// For Android emulator, use 10.0.2.2 to reference your computer's localhost
const LOCAL_IP = Platform.select({
  ios: 'https://glucopilot-8ed6389c53c8.herokuapp.com/',
  android: 'https://glucopilot-8ed6389c53c8.herokuapp.com/',
  default: 'https://glucopilot-8ed6389c53c8.herokuapp.com/',
});

// Try to import from Config first, then fallback to hardcoded values
const getApiBaseUrl = () => {
  // Check for environment variable from .env file via react-native-config
  if (Config.API_BASE_URL) {
    return Config.API_BASE_URL;
  }

  // If LOCAL_IP is a full URL (starts with http), use it as-is
  if (typeof LOCAL_IP === 'string' && LOCAL_IP.startsWith('http')) {
    return LOCAL_IP;
  }

  // Otherwise use platform-specific fallbacks
  return Platform.OS === 'web'
    ? 'http://localhost:8000'
    : `http://${LOCAL_IP}:8000`;
};

// Always use Config value if set, otherwise fallback to defaults
export const API_BASE_URL = getApiBaseUrl();
export const ENABLE_API_LOGS = __DEV__;

// For debugging
if (__DEV__) {
  console.log(`API configured to connect to: ${API_BASE_URL}`);
}
