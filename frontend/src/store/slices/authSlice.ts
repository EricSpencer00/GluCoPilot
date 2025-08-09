import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../../services/api';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { persistor } from '../store';
import * as Updates from 'expo-updates';

// Interfaces
interface User {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
}

interface AuthState {
  user: User | null;
  token: string | null;
  isLoading: boolean;
  error: string | null;
  isNewRegistration: boolean;
}

// Initial state
const initialState: AuthState = {
  user: null,
  token: null,
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
      
      // Store token in AsyncStorage
      await AsyncStorage.setItem('auth_token', token);

      // Fetch user profile
      const userRes = await api.get('/auth/me', {
        headers: { Authorization: `Bearer ${token}` },
      });

      return { user: userRes.data, token };
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
      
      // Store token in AsyncStorage
      await AsyncStorage.setItem('auth_token', token);

      // Fetch user profile
      const userRes = await api.get('/auth/me', {
        headers: { Authorization: `Bearer ${token}` },
      });

      return { user: userRes.data, token };
    } catch (error: any) {
      return rejectWithValue(error.response?.data?.detail || 'Registration failed');
    }
  }
);

export const logout = createAsyncThunk('auth/logout', async () => {
  // Clear token from AsyncStorage
  await AsyncStorage.removeItem('auth_token');
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
      state.isNewRegistration = true; // Set flag for new registration
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
    });
    builder.addCase(logout.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });
  },
});

export const { clearError, clearNewRegistrationFlag } = authSlice.actions;
export default authSlice.reducer;
