// Centralized configuration for API URLs

const ENV = 'development'; // Force development environment for local dev

const CONFIG = {
  development: {
    API_BASE_URL: 'http://localhost:8000',
    ENABLE_API_LOGS: true, // Enable API logging for debugging
  },
  production: {
    API_BASE_URL: 'https://api.glucopilot.com', // Updated production URL
    ENABLE_API_LOGS: false,
  },
};

export const API_BASE_URL = CONFIG[ENV].API_BASE_URL;
export const ENABLE_API_LOGS = CONFIG[ENV].ENABLE_API_LOGS;
