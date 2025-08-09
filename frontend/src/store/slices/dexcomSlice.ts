import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import api from '../../services/api';

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
      const response = await api.post('/auth/connect-dexcom', {
        username,
        password,
        ous: false // Default to US servers
      });
      
      return response.data;
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
