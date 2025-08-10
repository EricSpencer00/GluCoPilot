import axios from 'axios';
import Constants from 'expo-constants';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_BASE_URL, ENABLE_API_LOGS } from '../config';
import { setReduxDispatch } from './reduxDispatch';
import { setToken } from '../store/slices/authSlice';

// Create axios instance with default config
const api = axios.create({
  baseURL: API_BASE_URL, // Base URL without /api/v1 to allow more flexibility in paths
  timeout: 15000, // Increased timeout for slower connections
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add request interceptor to include auth token
api.interceptors.request.use(
  async (config) => {
    // Get token from secure storage
    const token = await AsyncStorage.getItem('auth_token');
    
    // If token exists, add to headers
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }

    // Add /api/v1 prefix if not already present and not an absolute URL
    if (config.url && !config.url.startsWith('http') && !config.url.startsWith('/api/v1/')) {
      config.url = `/api/v1${config.url}`;
    }
    
    // Log requests in development
    if (ENABLE_API_LOGS) {
      console.log(`API Request: ${config.method?.toUpperCase()} ${config.url}`, {
        headers: config.headers,
        data: config.data,
        params: config.params
      });
    }
    
    return config;
  },
  (error) => {
    if (ENABLE_API_LOGS) {
      console.error('API Request Error:', error);
    }
    return Promise.reject(error);
  }
);

// Add response interceptor to handle common errors
api.interceptors.response.use(
  (response) => {
    // Log successful responses in development
    if (ENABLE_API_LOGS) {
      console.log(`API Response: ${response.status} ${response.config.url}`, {
        data: response.data
      });
    }
    return response;
  },
  async (error) => {
    if (ENABLE_API_LOGS) {
      console.error('API Response Error:', {
        url: error.config?.url,
        status: error.response?.status,
        data: error.response?.data,
        message: error.message
      });
    }
    
    const originalRequest = error.config;
    
    // Handle 401 Unauthorized errors with refresh logic
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      try {
        const refreshToken = await AsyncStorage.getItem('refresh_token');
        if (refreshToken) {
          // Attempt to refresh the access token
          const refreshResponse = await api.post('/auth/refresh', { refresh_token: refreshToken });
          const { access_token: newToken, refresh_token: newRefreshToken } = refreshResponse.data;
          if (newToken) {
            await AsyncStorage.setItem('auth_token', newToken);
            setReduxDispatch(setToken(newToken));
            if (newRefreshToken) {
              await AsyncStorage.setItem('refresh_token', newRefreshToken);
            }
            // Update the Authorization header and retry the original request
            originalRequest.headers.Authorization = `Bearer ${newToken}`;
            return api(originalRequest);
          }
        }
        // If refresh fails, clear tokens
        await AsyncStorage.removeItem('auth_token');
        await AsyncStorage.removeItem('refresh_token');
      } catch (refreshError) {
        await AsyncStorage.removeItem('auth_token');
        await AsyncStorage.removeItem('refresh_token');
      }
      return Promise.reject(error);
    }
    
    return Promise.reject(error);
  }
);

export default api;
