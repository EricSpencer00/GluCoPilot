// Centralized configuration for API URLs

const ENV = process.env.NODE_ENV || 'development';

const CONFIG = {
  development: {
    API_BASE_URL: 'http://localhost:8000/api/v1',
  },
  production: {
    API_BASE_URL: '',
  },
};

export const API_BASE_URL = CONFIG[ENV].API_BASE_URL;
