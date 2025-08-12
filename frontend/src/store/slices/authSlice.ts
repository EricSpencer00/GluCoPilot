import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { User } from '../../types/User';
import api from '../../services/api';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { persistor } from '../store';
import * as Updates from 'expo-updates';

// Interfaces


interface AuthState {
  user: User | null;
  token: string | null;
  refreshToken: string | null;
  isLoading: boolean;
  error: string | null;
  isNewRegistration: boolean;
}

// Initial state
const initialState: AuthState = {
  user: null,
  token: null,
  refreshToken: null,
  isLoading: false,
  error: null,
  isNewRegistration: false,
};

// Async thunks
export const login = createAsyncThunk(
  'auth/login',
  async (
    { email, password }: { email: string; password: string },
    { rejectWithValue }
  ) => {
    try {
      // Backend expects username; map email to username for now
      const tokenRes = await api.post('/auth/login', {
        username: email,
        password,
      });
      const token: string = tokenRes.data.access_token;
      const refreshToken: string = tokenRes.data.refresh_token;
      
      // Make sure we have both tokens
      if (!token) {
        throw new Error('No access token returned from server');
      }
      
      if (!refreshToken) {
        throw new Error('No refresh token returned from server');
      }
      await AsyncStorage.multiSet([
        ['auth_token', token],
        ['refresh_token', refreshToken]
      ]);
      
      console.log('Tokens saved to AsyncStorage - Access:', !!token, 'Refresh:', !!refreshToken);

      // Fetch user profile
      const userRes = await api.get('/auth/me', {
        headers: { Authorization: `Bearer ${token}` },
      });

      return { user: userRes.data, token, refreshToken };
    } catch (error: any) {
      return rejectWithValue(error.response?.data?.detail || 'Login failed');
    }
  }
);

export const register = createAsyncThunk(
  'auth/register',
  async (
    userData: { email: string; password: string; first_name: string; last_name: string },
    { rejectWithValue }
  ) => {
    try {
      // Use email as username for now to satisfy backend schema
      await api.post('/auth/register', {
        username: userData.email,
        email: userData.email,
        password: userData.password,
        first_name: userData.first_name,
        last_name: userData.last_name,
      });

      // Auto login after registration
      const loginRes = await api.post('/auth/login', {
        username: userData.email,
        password: userData.password,
      });
      
      const token: string = loginRes.data.access_token;
      const refreshToken: string = loginRes.data.refresh_token;
      
      // Make sure we have both tokens
      if (!token) {
        throw new Error('No access token returned from server');
      }
      
      if (!refreshToken) {
        throw new Error('No refresh token returned from server');
      }
      await AsyncStorage.multiSet([
        ['auth_token', token],
        ['refresh_token', refreshToken]
      ]);
      
      console.log('Tokens saved to AsyncStorage after registration - Access:', !!token, 'Refresh:', !!refreshToken);

      // Fetch user profile
      const userRes = await api.get('/auth/me', {
        headers: { Authorization: `Bearer ${token}` },
      });

      return { user: userRes.data, token, refreshToken };
    } catch (error: any) {
      return rejectWithValue(error.response?.data?.detail || 'Registration failed');
    }
  }
);

export const logout = createAsyncThunk('auth/logout', async () => {
  // Clear tokens from AsyncStorage
  await AsyncStorage.removeItem('auth_token');
  await AsyncStorage.removeItem('refresh_token');
  // Purge redux-persist state to fully clear auth
  await persistor.purge();
  // Force a hard reload of the app to clear all in-memory state and interceptors
  if (Updates?.reloadAsync) {
    await Updates.reloadAsync();
  }
  return null;
});

// Slice
const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
    },
    clearNewRegistrationFlag: (state) => {
      state.isNewRegistration = false;
    },
    setToken: (state, action) => {
      state.token = action.payload;
    },
    setRefreshToken: (state, action) => {
      state.refreshToken = action.payload;
    },
  },
  extraReducers: (builder) => {
    // Login
    builder.addCase(login.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(login.fulfilled, (state, action) => {
      state.isLoading = false;
      state.user = action.payload.user;
      state.token = action.payload.token;
      state.refreshToken = action.payload.refreshToken;
      console.log('[AUTH SLICE] Setting tokens after login - Access:', !!action.payload.token, 'Refresh:', !!action.payload.refreshToken);
    });
    builder.addCase(login.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });

    // Register
    builder.addCase(register.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(register.fulfilled, (state, action) => {
      state.isLoading = false;
      state.user = action.payload.user;
      state.token = action.payload.token;
      state.refreshToken = action.payload.refreshToken;
      state.isNewRegistration = true; // Set flag for new registration
      console.log('[AUTH SLICE] Setting tokens after registration - Access:', !!action.payload.token, 'Refresh:', !!action.payload.refreshToken);
    });
    builder.addCase(register.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });

    // Logout
    builder.addCase(logout.pending, (state) => {
      state.isLoading = true;
    });
    builder.addCase(logout.fulfilled, (state) => {
      state.isLoading = false;
      state.user = null;
      state.token = null;
      state.refreshToken = null;
    });
    builder.addCase(logout.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
      state.user = null;
      state.token = null;
      state.refreshToken = null;
    });
  },
});

export const { clearError, clearNewRegistrationFlag, setToken, setRefreshToken } = authSlice.actions;
export default authSlice.reducer;
