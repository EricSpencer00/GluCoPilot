import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../../services/api';

// Interfaces
interface Recommendation {
  id: string;
  content: string;
  created_at: string;
  type: string;
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
      const response = await api.get('/api/ai/recommendations');
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.response?.data?.message || 'Failed to fetch recommendations');
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
