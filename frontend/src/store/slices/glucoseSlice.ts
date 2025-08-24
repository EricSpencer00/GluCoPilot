import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../../services/api';
import { secureStorage, DEXCOM_USERNAME_KEY, DEXCOM_PASSWORD_KEY, DEXCOM_OUS_KEY } from '../../services/secureStorage';

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
      const days = Math.max(1, Math.ceil(hours / 24));
      console.log(`Fetching glucose data for ${hours} hours (${days} days)`);

      const [readingsRes, latestRes, statsRes] = await Promise.all([
        api.get('/api/v1/glucose/readings', { params: { limit: hours * 12 } }), // ~5-min intervals
        api.get('/api/v1/glucose/latest'),
        api.get('/api/v1/glucose/stats', { params: { days } }),
      ]);

      console.log(`Fetched ${readingsRes.data?.length || 0} readings`);
      
      return {
        readings: readingsRes.data || [],
        latest_reading: latestRes.data || null,
        stats: statsRes.data || null,
      };
    } catch (error: any) {
      console.error('Error fetching glucose data:', error.message);
      return rejectWithValue(
        error.response?.data?.detail || 'Failed to fetch glucose data'
      );
    }
  }
);

export const syncDexcomData = createAsyncThunk(
  'glucose/syncDexcom',
  async (_: void, { rejectWithValue }) => {
    try {
      console.log('Syncing Dexcom data...');
      
      // Retrieve stored Dexcom credentials (if any)
      const username = await secureStorage.getItem(DEXCOM_USERNAME_KEY);
      const password = await secureStorage.getItem(DEXCOM_PASSWORD_KEY);
      const ousRaw = await secureStorage.getItem(DEXCOM_OUS_KEY);
      const ous = ousRaw === 'true' || ousRaw === '1';

      // If running stateless, the backend requires creds in the request body.
      if (!username || !password) {
        return rejectWithValue('Dexcom credentials not configured. Please connect Dexcom in Settings.');
      }

      // Trigger sync providing credentials
      await api.post('/api/v1/glucose/sync', { username, password, ous });
      console.log('Sync completed, fetching updated data');

      // After sync, refresh data (default 24h)
      const [readingsRes, latestRes, statsRes] = await Promise.all([
        api.get('/api/v1/glucose/readings', { params: { limit: 24 * 12 } }),
        api.get('/api/v1/glucose/latest'),
        api.get('/api/v1/glucose/stats', { params: { days: 1 } }),
      ]);

      return {
        readings: readingsRes.data || [],
        latest_reading: latestRes.data || null,
        stats: statsRes.data || null,
      };
    } catch (error: any) {
      console.error('Error syncing Dexcom data:', error.message);
      return rejectWithValue(
        error.response?.data?.detail || 'Failed to sync Dexcom data'
      );
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
