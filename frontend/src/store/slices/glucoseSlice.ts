import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../../services/api';
import { secureStorage, DEXCOM_USERNAME_KEY, DEXCOM_PASSWORD_KEY, DEXCOM_OUS_KEY } from '../../services/secureStorage';
import { fetchDexcomTrends } from '../../services/dexcomTrendsService';

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

      // If we have Dexcom credentials stored on device, prefer stateless endpoints
      const username = await secureStorage.getItem(DEXCOM_USERNAME_KEY);
      const password = await secureStorage.getItem(DEXCOM_PASSWORD_KEY);
      const ousRaw = await secureStorage.getItem(DEXCOM_OUS_KEY);
      const ous = ousRaw === 'true' || ousRaw === '1';

      if (username && password) {
        console.log('Using stateless Dexcom endpoints to fetch readings');
        // Call stateless sync to fetch readings (no DB writes)
        const syncRes = await api.post('/api/v1/glucose/stateless/sync', { username, password, ous, hours });
        const readings = syncRes.data?.readings || [];
        // Assume readings are ordered newest first; pick first as latest if available
        const latest_reading = readings && readings.length > 0 ? readings[0] : null;
        // Get trends/stats via the trends service (it will include creds if available)
        let stats = null;
        try {
          stats = await fetchDexcomTrends(days);
        } catch (e) {
          console.warn('Failed to fetch Dexcom trends:', e);
          stats = null;
        }

        console.log(`Fetched ${readings.length} stateless readings`);
        return {
          readings,
          latest_reading,
          stats,
        };
      }

      // No Dexcom credentials available on device. In stateless deployments the server
      // has no DB tables and calling the legacy endpoints will cause sqlite errors.
      // Return an empty dataset so UI can prompt the user to connect Dexcom instead of
      // making DB-backed requests.
      console.warn('No Dexcom credentials found on device; skipping server DB-backed glucose requests');
      return {
        readings: [],
        latest_reading: null,
        stats: null,
      };

      // Fallback: server-backed endpoints that rely on a DB
      // const [readingsRes, latestRes, statsRes] = await Promise.all([
      //   api.get('/api/v1/glucose/readings', { params: { limit: hours * 12 } }), // ~5-min intervals
      //   api.get('/api/v1/glucose/latest'),
      //   api.get('/api/v1/glucose/stats', { params: { days } }),
      // ]);
      //
      // console.log(`Fetched ${readingsRes.data?.length || 0} readings`);
      //
      // return {
      //   readings: readingsRes.data || [],
      //   latest_reading: latestRes.data || null,
      //   stats: statsRes.data || null,
      // };
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

      // Prefer stateless sync endpoint which returns readings directly (no DB writes)
      try {
        const statelessRes = await api.post('/api/v1/glucose/stateless/sync', { username, password, ous });
        const readings = statelessRes.data?.readings || [];
        const latest_reading = readings && readings.length > 0 ? readings[0] : null;
        let stats = null;
        try {
          stats = await fetchDexcomTrends(1);
        } catch (e) {
          console.warn('Failed to fetch Dexcom trends after stateless sync:', e);
          stats = null;
        }

        console.log('Stateless sync completed, returning readings');
        return {
          readings,
          latest_reading,
          stats,
        };
      } catch (statelessErr: any) {
        // If stateless endpoint fails for some reason, surface the error to caller
        console.error('Stateless Dexcom sync error:', statelessErr);
        return rejectWithValue(statelessErr.response?.data?.detail || 'Failed to sync Dexcom data');
      }

      // NOTE: For DB-backed deployments the legacy flow would POST /api/v1/glucose/sync and
      // then GET readings/latest/stats. That code is intentionally not executed in
      // stateless deployments to avoid triggering missing-DB errors.
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
