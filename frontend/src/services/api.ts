import axios from 'axios';
import Constants from 'expo-constants';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_BASE_URL, ENABLE_API_LOGS } from '../config';
import { setReduxDispatch, getReduxDispatch } from './reduxDispatch';
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
    console.log('Token used for API:', token); // DEBUG LOG
    // If token exists, add to headers
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    } else {
      console.error('No auth token found for API request');
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

// Track if we're currently refreshing the token to prevent multiple refresh attempts
let isRefreshing = false;
// Queue of requests to retry after token refresh
let refreshQueue: ((token: string) => void)[] = [];

// Function to process the queue of failed requests
const processQueue = (token: string) => {
  refreshQueue.forEach(callback => callback(token));
  refreshQueue = [];
};

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
    
    // Skip refresh token endpoint to avoid endless loop
    const isRefreshEndpoint = originalRequest.url?.includes('/auth/refresh');
    
    // Handle 401 or 403 errors with refresh logic if not already retrying and not a refresh request
    if ((error.response?.status === 401 || error.response?.status === 403) && 
        !originalRequest._retry && 
        !isRefreshEndpoint) {
      
      originalRequest._retry = true;
      
      // If a token refresh is already in progress, add this request to the queue
      if (isRefreshing) {
        return new Promise(resolve => {
          refreshQueue.push((token: string) => {
            originalRequest.headers.Authorization = `Bearer ${token}`;
            resolve(api(originalRequest));
          });
        });
      }
      
      isRefreshing = true;
      
      try {
        console.log('Attempting to refresh token after 401/403 error');
        const refreshToken = await AsyncStorage.getItem('refresh_token');
        
        if (!refreshToken) {
          console.log('No refresh token available, cannot refresh');
          throw new Error('No refresh token');
        }
        
        // Create a new axios instance without interceptors to avoid recursion
        const axiosNoInterceptors = axios.create({
          baseURL: API_BASE_URL,
          timeout: 15000,
          headers: { 'Content-Type': 'application/json' }
        });
        
        // Attempt to refresh the access token
        const refreshResponse = await axiosNoInterceptors.post('/api/v1/auth/refresh', 
          { refresh_token: refreshToken },
          { headers: { 'Content-Type': 'application/json' } }
        );
        
        const { access_token: newToken, refresh_token: newRefreshToken } = refreshResponse.data;
        
        if (!newToken) {
          throw new Error('Token refresh failed - no new token received');
        }
        
        console.log('Token refreshed successfully after 401/403 error');
        
        // Store new tokens and update Redux state
        await AsyncStorage.setItem('auth_token', newToken);
        if (newRefreshToken) {
          await AsyncStorage.setItem('refresh_token', newRefreshToken);
        }
        
        // Update Redux state only if we have the dispatch function
        const dispatch = getReduxDispatch();
        if (dispatch) {
          dispatch(setToken(newToken));
        }
        
        // Update the Authorization header for the original request
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        
        // Process any queued requests with the new token
        processQueue(newToken);
        
        // Return a retry of the original request
        return api(originalRequest);
      } catch (refreshError) {
        console.error('Token refresh failed:', refreshError);
        
        // Clear tokens on refresh failure
        await AsyncStorage.removeItem('auth_token');
        await AsyncStorage.removeItem('refresh_token');
        
        // Update Redux state to clear token
        const dispatch = getReduxDispatch();
        if (dispatch) {
          dispatch(setToken(null));
        }
        
        // Reject all queued requests
        refreshQueue.forEach(callback => callback(''));
        refreshQueue = [];
        
        return Promise.reject(error);
      } finally {
        isRefreshing = false;
      }
    }
    
    return Promise.reject(error);
  }
);

export default api;
