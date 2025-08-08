import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import axios from 'axios';

// Interfaces
interface GlucoseReading {
  id: string;
  value: number;
  timestamp: string;
  trend: string;
  is_high: boolean;
  is_low: boolean;
}

interface GlucoseStats {
  time_in_range: number;
  time_below_range: number;
  time_above_range: number;
  avg_glucose: number;
}

interface GlucoseState {
  readings: GlucoseReading[];
  latestReading: GlucoseReading | null;
  stats: GlucoseStats | null;
  isLoading: boolean;
  error: string | null;
  lastSync: string | null;
}

// Initial state
const initialState: GlucoseState = {
  readings: [],
  latestReading: null,
  stats: null,
  isLoading: false,
  error: null,
  lastSync: null,
};

// Async thunks
export const fetchGlucoseData = createAsyncThunk(
  'glucose/fetchData',
  async ({ hours = 24 }: { hours?: number }, { rejectWithValue }) => {
    try {
      const response = await axios.get(`/api/glucose/readings?hours=${hours}`);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.response?.data?.message || 'Failed to fetch glucose data');
    }
  }
);

export const syncDexcomData = createAsyncThunk(
  'glucose/syncDexcom',
  async (_, { rejectWithValue }) => {
    try {
      const response = await axios.post('/api/glucose/sync/dexcom');
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.response?.data?.message || 'Failed to sync Dexcom data');
    }
  }
);

// Slice
const glucoseSlice = createSlice({
  name: 'glucose',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
    },
  },
  extraReducers: (builder) => {
    // Fetch glucose data
    builder.addCase(fetchGlucoseData.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(fetchGlucoseData.fulfilled, (state, action) => {
      state.isLoading = false;
      state.readings = action.payload.readings;
      state.latestReading = action.payload.latest_reading;
      state.stats = action.payload.stats;
    });
    builder.addCase(fetchGlucoseData.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });

    // Sync Dexcom data
    builder.addCase(syncDexcomData.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(syncDexcomData.fulfilled, (state, action) => {
      state.isLoading = false;
      state.readings = action.payload.readings;
      state.latestReading = action.payload.latest_reading;
      state.stats = action.payload.stats;
      state.lastSync = new Date().toISOString();
    });
    builder.addCase(syncDexcomData.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });
  },
});

export const { clearError } = glucoseSlice.actions;
export default glucoseSlice.reducer;
