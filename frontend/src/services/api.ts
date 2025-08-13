import axios from 'axios';
import { secureStorage, AUTH_TOKEN_KEY, REFRESH_TOKEN_KEY } from './secureStorage';
import { API_BASE_URL, ENABLE_API_LOGS } from '../config';
import { setReduxDispatch, getReduxDispatch } from './reduxDispatch';
import { setToken, setRefreshToken } from '../store/slices/authSlice';


// Create axios instance with default config
const api = axios.create({
  baseURL: API_BASE_URL, // Base URL without /api/v1 to allow more flexibility in paths
  timeout: 15000, // Increased timeout for slower connections
  headers: {
    'Content-Type': 'application/json',
  },
});

const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));


// Add request interceptor to include auth token
api.interceptors.request.use(
  async (config) => {
    // Get token from secure storage
    const token = await secureStorage.getItem(AUTH_TOKEN_KEY);
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
        headers: { ...config.headers, Authorization: config.headers?.Authorization ? '[REDACTED]' : undefined },
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
        const refreshToken = await secureStorage.getItem(REFRESH_TOKEN_KEY);
        if (!refreshToken) {
          throw new Error('No refresh token');
        }

        // Create a new axios instance without interceptors to avoid recursion
        const axiosNoInterceptors = axios.create({
          baseURL: API_BASE_URL,
          timeout: 30000, // Increase timeout for refresh token requests
          headers: { 'Content-Type': 'application/json' }
        });

        // Attempt to refresh the access token
        let refreshResponse;
        try {
          // Ensure the URL is correctly formed with /api/v1 prefix
          const refreshUrl = '/api/v1/auth/refresh';
          
          refreshResponse = await axiosNoInterceptors.post(refreshUrl,
            { refresh_token: refreshToken },
            { headers: { 'Content-Type': 'application/json' } }
          );
        } catch (refreshErr: any) {
          // Enhanced error logging
          if (ENABLE_API_LOGS) {
            console.error('Refresh endpoint error:', {
              status: refreshErr?.response?.status,
              data: refreshErr?.response?.data,
              message: refreshErr?.message,
              url: refreshErr?.config?.url
            });
          }

          // Retry once on network/5xx errors with small backoff
          const status = refreshErr?.response?.status;
          if (!status || (status >= 500 && status < 600)) {
            await delay(1000);
            const refreshUrl = '/api/v1/auth/refresh';
            refreshResponse = await axiosNoInterceptors.post(refreshUrl,
              { refresh_token: refreshToken },
              { headers: { 'Content-Type': 'application/json' } }
            );
          } else {
            throw refreshErr;
          }
        }

        if (ENABLE_API_LOGS) {
          console.log('Refresh token response received:', {
            status: refreshResponse.status,
            hasAccessToken: !!refreshResponse.data.access_token,
            hasRefreshToken: !!refreshResponse.data.refresh_token
          });
        }

        const { access_token: newToken, refresh_token: newRefreshToken } = refreshResponse.data;

        if (!newToken) {
          throw new Error('Token refresh failed - no new token received');
        }

        // Store new tokens securely
        await secureStorage.setItem(AUTH_TOKEN_KEY, newToken);
        await secureStorage.setItem(REFRESH_TOKEN_KEY, newRefreshToken || refreshToken);
        
        // Update Redux state with both tokens
        const dispatch = getReduxDispatch();
        if (dispatch) {
          dispatch(setToken(newToken));
          dispatch(setRefreshToken(newRefreshToken || refreshToken));
        }

        // Update the Authorization header for the original request
        originalRequest.headers.Authorization = `Bearer ${newToken}`;

        // Process any queued requests with the new token
        processQueue(newToken);

        // Return a retry of the original request
        return api(originalRequest);
      } catch (refreshError: any) {
        // Log refresh error details
        if (ENABLE_API_LOGS) {
          console.error('Token refresh failed:', refreshError?.response?.data || refreshError);
        }
        // Only clear tokens on explicit 401 from refresh
        const status = refreshError?.response?.status;
        if (status === 401) {
          await secureStorage.removeItem(AUTH_TOKEN_KEY);
          await secureStorage.removeItem(REFRESH_TOKEN_KEY);
          // Update Redux state to clear token
          const dispatch = getReduxDispatch();
          if (dispatch) {
            dispatch(setToken(null));
            dispatch(setRefreshToken(null));
          }
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
