import { jwtDecode } from 'jwt-decode';
// Helper to decode JWT and extract minimal user info
function extractUserFromToken(token: string): Partial<User> | null {
  try {
    const decoded: any = jwtDecode(token);
    // Always provide at least id and email for navigation logic
    const id = decoded.sub || decoded.email || decoded.user_id || '';
    const email = decoded.email || '';
    if (!id || !email) return null;
    return {
      id,
      email,
      first_name: decoded.given_name || decoded.first_name || '',
      last_name: decoded.family_name || decoded.last_name || '',
    };
  } catch (e) {
    return null;
  }
}

// Thunk to get current user, fallback to JWT decode if /auth/me 404s
export const getCurrentUser = createAsyncThunk(
  'auth/getCurrentUser',
  async (token: string, { rejectWithValue }) => {
    try {
      const userRes = await api.get('/auth/me', {
        headers: { Authorization: `Bearer ${token}` },
      });
      return userRes.data;
    } catch (error: any) {
      if (error.response?.status === 404) {
        // Fallback: decode JWT for minimal user info
        const user = extractUserFromToken(token);
        if (user) return user;
        return rejectWithValue('Could not extract user info from token');
      }
      return rejectWithValue(error.response?.data?.detail || 'Failed to fetch user');
    }
  }
);
// Social login thunk
export const socialLogin = createAsyncThunk(
  'auth/socialLogin',
  async (
    { firstName, lastName, email, provider, idToken }: { firstName: string; lastName: string; email: string; provider: string; idToken: string },
    { rejectWithValue }
  ) => {
    try {
      // Call your backend social login endpoint with Apple/Google token in Authorization header
      const tokenRes = await api.post(
        '/auth/social-login',
        {
          first_name: firstName,
          last_name: lastName,
          email,
          provider,
          id_token: idToken,
        },
        {
          headers: { Authorization: `Bearer ${idToken}` },
        }
      );
      const token: string = tokenRes.data.access_token;
      const refreshToken: string = tokenRes.data.refresh_token;

      if (!token) throw new Error('No access token returned from server');
      if (!refreshToken) throw new Error('No refresh token returned from server');

      setAuthTokens(token, refreshToken);
      await secureStorage.setItem(AUTH_TOKEN_KEY, token);
      await secureStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);

      // @ts-ignore
      if (typeof window === 'undefined' && typeof global !== 'undefined' && (global as any).dispatch) {
        (global as any).dispatch(setToken(token));
        (global as any).dispatch(setRefreshToken(refreshToken));
      }

      // Fetch user profile (handle stateless mode)
      let user;
      let isNewRegistration = false;
      try {
        user = await (await api.get('/auth/me', { headers: { Authorization: `Bearer ${token}` } })).data;
      } catch (error: any) {
        if (error.response?.status === 404) {
          // If backend doesn't have a user record yet, try to decode tokens.
          const decodedAccess = extractUserFromToken(token);
          const decodedIdToken = extractUserFromToken(idToken);
          // Debug: show what we could decode from access and id tokens
          // eslint-disable-next-line no-console
          console.debug('socialLogin token decode', { hasAccessToken: !!token, hasIdToken: !!idToken, decodedAccess, decodedIdToken });
          user = decodedAccess || decodedIdToken || null;
          if (!user) {
            return rejectWithValue('Could not extract user info from token');
          }
          // Mark this as a new registration flow so UI can prompt Dexcom connection
          isNewRegistration = true;
        } else {
          throw error;
        }
      }
      return { user, token, refreshToken, isNewRegistration };
    } catch (error: any) {
      return rejectWithValue(error.response?.data?.detail || 'Social login failed');
    }
  }
);
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { User } from '../../types/User';
import api, { setAuthTokens } from '../../services/api';
import { secureStorage, AUTH_TOKEN_KEY, REFRESH_TOKEN_KEY } from '../../services/secureStorage';
import { persistor } from '../store';

// Interfaces


interface AuthState {
  user: User | null;
  token: string | null;
  refreshToken: string | null;
  isLoading: boolean;
  error: string | null;
  isNewRegistration: boolean;
  isLoggingOut: boolean;
}

// Initial state
const initialState: AuthState = {
  user: null,
  token: null,
  refreshToken: null,
  isLoading: false,
  error: null,
  isNewRegistration: false,
  isLoggingOut: false,
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

      // Seed in-memory tokens immediately to avoid races
      setAuthTokens(token, refreshToken);

      await secureStorage.setItem(AUTH_TOKEN_KEY, token);
      await secureStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);

      // Immediately update Redux state with tokens
      // @ts-ignore
      if (typeof window === 'undefined' && typeof global !== 'undefined' && (global as any).dispatch) {
        (global as any).dispatch(setToken(token));
        (global as any).dispatch(setRefreshToken(refreshToken));
      }

      // Fetch user profile (handle stateless mode)
      let user;
      try {
        user = await (await api.get('/auth/me', { headers: { Authorization: `Bearer ${token}` } })).data;
      } catch (error: any) {
        if (error.response?.status === 404) {
          user = extractUserFromToken(token);
        } else {
          throw error;
        }
      }
      return { user, token, refreshToken };
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

      // Seed in-memory tokens immediately
      setAuthTokens(token, refreshToken);

      await secureStorage.setItem(AUTH_TOKEN_KEY, token);
      await secureStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);

      // Immediately update Redux state with tokens
      // @ts-ignore
      if (typeof window === 'undefined' && typeof global !== 'undefined' && (global as any).dispatch) {
        (global as any).dispatch(setToken(token));
        (global as any).dispatch(setRefreshToken(refreshToken));
      }

      // Fetch user profile (handle stateless mode)
      let user;
      try {
        user = await (await api.get('/auth/me', { headers: { Authorization: `Bearer ${token}` } })).data;
      } catch (error: any) {
        if (error.response?.status === 404) {
          user = extractUserFromToken(token);
        } else {
          throw error;
        }
      }
      return { user, token, refreshToken };
    } catch (error: any) {
      return rejectWithValue(error.response?.data?.detail || 'Registration failed');
    }
  }
);


export const logout = createAsyncThunk('auth/logout', async () => {
  // Clear tokens from storage
  await secureStorage.removeItem(AUTH_TOKEN_KEY);
  await secureStorage.removeItem(REFRESH_TOKEN_KEY);
  // Clear in-memory tokens
  setAuthTokens(null, null);
  // Purge redux-persist state to fully clear auth
  try {
    if (persistor && persistor.purge) await persistor.purge();
  } catch (e) {
    // If purge fails, continue — not critical for logout flow
    // eslint-disable-next-line no-console
    console.warn('Could not purge persistor during logout:', e);
  }

  // Force a hard reload of the app to clear all in-memory state and interceptors
  // Note: In React Native CLI, we can't force reload like in Expo
  // The app will need to be manually restarted or use a navigation reset
  console.log('Logout complete. Please restart the app for a clean state.');
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
    setLoggingOut: (state, action) => {
      state.isLoggingOut = action.payload;
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
    });
    builder.addCase(login.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });

    // Social Login
    builder.addCase(socialLogin.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(socialLogin.fulfilled, (state, action) => {
      state.isLoading = false;
      state.user = action.payload.user;
      state.token = action.payload.token;
      state.refreshToken = action.payload.refreshToken;
      state.isNewRegistration = action.payload.isNewRegistration || false;
    });
    builder.addCase(socialLogin.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });

    // Register
    builder.addCase(register.pending, (state) => {
      state.isLoading = true;
      state.error = null;
      state.isLoggingOut = true;
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
