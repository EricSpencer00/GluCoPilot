import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../../services/api';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AI_RECOMMENDATION_FETCH_INTERVAL } from '../../constants/ai';

// Interfaces
interface Recommendation {
  id: number;
  recommendation_type: string;
  content: string;
  title: string;
  category: string;
  priority: string;
  confidence_score: number;
  context_data: any;
  timestamp: string;
}

interface AIState {
  recommendations: Recommendation[];
  isLoading: boolean;
  error: string | null;
}

// Initial state
const initialState: AIState = {
  recommendations: [],
  isLoading: false,
  error: null,
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
      if (typeof recommendations === 'string') {
        // If backend returns a single string, parse it into objects
        recommendations = parseRecommendationsString(recommendations);
      }
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

// Helper to parse a single string of recommendations into array of objects
function parseRecommendationsString(recommendationsString: string) {
  // Split by double newlines or ** markers
  const items = recommendationsString.split(/\n\n|(?=\*\*)/g).filter(Boolean);
  let id = 1;
  return items.map(item => {
    // Extract title (between ** ** or at start)
    const titleMatch = item.match(/\*\*(.*?)\*\*/);
    const title = titleMatch ? titleMatch[1].trim() : item.split('\n')[0].trim();
    const content = item.replace(/\*\*(.*?)\*\*/g, '').trim();
    return {
      id: id++,
      recommendation_type: '',
      content,
      title,
      category: '',
      priority: 'medium',
      confidence_score: 0,
      context_data: null,
      timestamp: new Date().toISOString(),
    };
  });
}

// Slice
const aiSlice = createSlice({
  name: 'ai',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
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
  },
});

export const { clearError } = aiSlice.actions;
export default aiSlice.reducer;
