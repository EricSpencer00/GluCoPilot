import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../../services/api';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AI_RECOMMENDATION_FETCH_INTERVAL } from '../../constants/ai';
import { getDetailedInsight } from '../../services/insightsService';

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
        // Use cached recommendations if available
        const cached = await AsyncStorage.getItem('ai_recommendations_cache');
        if (cached) {
          return JSON.parse(cached);
        }
        return [];
      }
      const response = await api.get('/api/v1/recommendations/recommendations');
      await AsyncStorage.setItem('ai_recommendations_last_fetch', now.toString());
      // Format recommendations for frontend: split title/content if needed
      let recommendations = response.data.recommendations;
      // No string fallback needed; backend always returns array of objects
      await AsyncStorage.setItem('ai_recommendations_cache', JSON.stringify(recommendations));
      return recommendations;
    } catch (error: any) {
      console.error('Error fetching AI recommendations:', error.message);
      // On error, try to use cache
      const cached = await AsyncStorage.getItem('ai_recommendations_cache');
      if (cached) {
        return JSON.parse(cached);
      }
      return rejectWithValue(error.response?.data?.message || 'Failed to fetch recommendations');
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
