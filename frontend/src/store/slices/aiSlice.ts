import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { secureStorage, DEXCOM_USERNAME_KEY, DEXCOM_PASSWORD_KEY, DEXCOM_OUS_KEY } from '../../services/secureStorage';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AI_RECOMMENDATION_FETCH_INTERVAL } from '../../constants/ai';
import { getDetailedInsight } from '../../services/insightsService';
import api from '../../services/api';

// Interfaces
interface Recommendation {
  title: string;
  description: string;
  category: string;
  priority: string;
  confidence: number;
  action: string;
  timing: string;
  context: any;
}

interface DetailedInsight {
  detail: string;
  original_recommendation: Recommendation;
  timestamp: string;
  recommendation_id: string;
  related_recommendations?: { title: string; description: string }[];
}

interface AIState {
  recommendations: Recommendation[];
  isLoading: boolean;
  error: string | null;
  detailedInsight: DetailedInsight | null;
  isLoadingDetailedInsight: boolean;
}

// Initial state
const initialState: AIState = {
  recommendations: [],
  isLoading: false,
  error: null,
  detailedInsight: null,
  isLoadingDetailedInsight: false,
};

// Async thunks
export const fetchRecommendations = createAsyncThunk(
  'ai/fetchRecommendations',
  async (_, { rejectWithValue }) => {
    try {
      const now = Date.now();
      const lastFetchStr = await AsyncStorage.getItem('ai_recommendations_last_fetch');
      const lastFetch = lastFetchStr ? parseInt(lastFetchStr, 10) : 0;
      if (now - lastFetch < AI_RECOMMENDATION_FETCH_INTERVAL) {
        const cached = await AsyncStorage.getItem('ai_recommendations_cache');
        if (cached) return JSON.parse(cached);
        return [];
      }

      // Require on-device Dexcom creds to call backend stateless AI endpoint
      const username = await secureStorage.getItem(DEXCOM_USERNAME_KEY);
      const password = await secureStorage.getItem(DEXCOM_PASSWORD_KEY);
      const ousFlag = (await secureStorage.getItem(DEXCOM_OUS_KEY)) === 'true';
      if (!username || !password) {
        console.warn('No Dexcom credentials on device — skipping backend AI recommendations');
        const cached = await AsyncStorage.getItem('ai_recommendations_cache');
        if (cached) {
          await AsyncStorage.setItem('ai_recommendations_last_fetch', now.toString());
          return JSON.parse(cached);
        }
        return [];
      }

      const payload = { username, password, ous: !!ousFlag };
      const response = await api.post('/api/v1/recommendations/stateless', payload);

      // Cache and return
      await AsyncStorage.setItem('ai_recommendations_last_fetch', now.toString());
      const recommendations = response.data.recommendations || response.data || [];
      await AsyncStorage.setItem('ai_recommendations_cache', JSON.stringify(recommendations));
      return recommendations;
    } catch (error: any) {
      console.error('Error fetching AI recommendations from backend:', error?.message || error);
      const cached = await AsyncStorage.getItem('ai_recommendations_cache');
      if (cached) return JSON.parse(cached);
      return rejectWithValue('Failed to fetch recommendations');
    }
  }
);

export const fetchDetailedInsight = createAsyncThunk(
  'ai/fetchDetailedInsight',
  async (recommendation: Recommendation, { rejectWithValue }) => {
    try {
      const result = await getDetailedInsight(recommendation);
      return result;
    } catch (error: any) {
      console.error('Error fetching detailed insight:', error.message);
      return rejectWithValue(error.response?.data?.message || 'Failed to fetch detailed insight');
    }
  }
);

// Slice
const aiSlice = createSlice({
  name: 'ai',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
    },
    clearDetailedInsight: (state) => {
      state.detailedInsight = null;
    },
  },
  extraReducers: (builder) => {
    // Fetch recommendations
    builder.addCase(fetchRecommendations.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(fetchRecommendations.fulfilled, (state, action) => {
      state.isLoading = false;
      state.recommendations = action.payload;
    });
    builder.addCase(fetchRecommendations.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });
    
    // Fetch detailed insight
    builder.addCase(fetchDetailedInsight.pending, (state) => {
      state.isLoadingDetailedInsight = true;
      state.error = null;
    });
    builder.addCase(fetchDetailedInsight.fulfilled, (state, action) => {
      state.isLoadingDetailedInsight = false;
      state.detailedInsight = action.payload;
    });
    builder.addCase(fetchDetailedInsight.rejected, (state, action) => {
      state.isLoadingDetailedInsight = false;
      state.error = action.payload as string;
    });
  },
});

export const { clearError, clearDetailedInsight } = aiSlice.actions;
export default aiSlice.reducer;
