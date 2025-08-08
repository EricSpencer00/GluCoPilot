import axios from 'axios';
import Constants from 'expo-constants';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Get the API base URL from Expo constants
const API_BASE_URL = Constants.expoConfig?.extra?.API_BASE_URL || 'http://localhost:8000';

// Create axios instance with default config
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
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
    
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Add response interceptor to handle common errors
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    
    // Handle 401 Unauthorized errors
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      
      // Clear tokens on auth error
      await AsyncStorage.removeItem('auth_token');
      
      // You could add token refresh logic here
      
      // For now, just reject the promise
      return Promise.reject(error);
    }
    
    return Promise.reject(error);
  }
);

export default api;
