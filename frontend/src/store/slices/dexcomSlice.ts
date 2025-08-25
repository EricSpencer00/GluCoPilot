import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import api from '../../services/api';
import { secureStorage, DEXCOM_USERNAME_KEY, DEXCOM_PASSWORD_KEY, DEXCOM_OUS_KEY } from '../../services/secureStorage';

interface DexcomState {
  isConnected: boolean;
  isLoading: boolean;
  error: string | null;
}

const initialState: DexcomState = {
  isConnected: false,
  isLoading: false,
  error: null,
};

export const loginToDexcom = createAsyncThunk(
  'dexcom/connect',
  async (
    { username, password }: { username: string; password: string },
    { rejectWithValue }
  ) => {
    try {
      // Use explicit stateless endpoint path to avoid interceptor prefix issues
      const endpoint = '/api/v1/glucose/stateless/sync';
      console.log('Calling Dexcom stateless sync endpoint:', endpoint);
      const response = await api.post(endpoint, {
        username,
        password,
        ous: false,
      });
      console.log('Dexcom stateless sync response:', response.status, response.data && { readingsCount: response.data.readings?.length });

      if (response.data?.readings) {
        // Persist creds securely on device for future stateless calls
        try {
          await secureStorage.setItem(DEXCOM_USERNAME_KEY, username);
          await secureStorage.setItem(DEXCOM_PASSWORD_KEY, password);
          await secureStorage.setItem(DEXCOM_OUS_KEY, 'false');
          console.log('Dexcom credentials persisted to secure storage');
          // Verify by reading back
          try {
            const storedUser = await secureStorage.getItem(DEXCOM_USERNAME_KEY);
            const storedPass = await secureStorage.getItem(DEXCOM_PASSWORD_KEY);
            const storedOus = await secureStorage.getItem(DEXCOM_OUS_KEY);
            console.log('Stored credential check:', { storedUser: !!storedUser, storedPass: !!storedPass, storedOus });
          } catch (readErr) {
            console.error('Error reading back stored Dexcom credentials:', readErr);
          }
        } catch (storageErr) {
          console.error('Failed to persist Dexcom credentials:', storageErr);
          // Still return success so UX proceeds, but surface a warning
        }
        return { success: true, message: 'Connected', new_readings: response.data.readings.length };
      }
      return rejectWithValue('Unexpected response from Dexcom stateless sync');
    } catch (error: any) {
      console.error('Dexcom connection error:', error?.response?.status, error?.response?.data || error?.message || error);
      // If backend returned detailed message, include it
      const detail = error?.response?.data?.detail || error?.response?.data || error?.message || 'Dexcom connection failed';
      return rejectWithValue(detail);
    }
  }
);

const dexcomSlice = createSlice({
  name: 'dexcom',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
    },
    setConnected: (state, action: PayloadAction<boolean>) => {
      state.isConnected = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder.addCase(loginToDexcom.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(loginToDexcom.fulfilled, (state) => {
      state.isLoading = false;
      state.isConnected = true;
      state.error = null;
    });
    builder.addCase(loginToDexcom.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });
  },
});

export const { clearError, setConnected } = dexcomSlice.actions;
export default dexcomSlice.reducer;
