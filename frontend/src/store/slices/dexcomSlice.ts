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
      // Use stateless endpoint
      const response = await api.post('/glucose/stateless/sync', {
        username,
        password,
        ous: false
      });

      if (response.data?.readings) {
        // Persist creds securely on device for future stateless calls
        await secureStorage.setItem(DEXCOM_USERNAME_KEY, username);
        await secureStorage.setItem(DEXCOM_PASSWORD_KEY, password);
        await secureStorage.setItem(DEXCOM_OUS_KEY, 'false');
        return { success: true, message: 'Connected', new_readings: response.data.readings.length };
      }
      return rejectWithValue('Unexpected response from Dexcom stateless sync');
    } catch (error: any) {
      console.error("Dexcom connection error:", error);
      return rejectWithValue(error.response?.data?.detail || 'Dexcom connection failed');
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
