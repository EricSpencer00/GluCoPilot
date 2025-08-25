import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { secureStorage, DEXCOM_USERNAME_KEY, DEXCOM_PASSWORD_KEY, DEXCOM_OUS_KEY } from '../../services/secureStorage';
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
  async (_, { rejectWithValue, getState }) => {
    try {
      const now = Date.now();
      const lastFetchStr = await AsyncStorage.getItem('ai_recommendations_last_fetch');
      const lastFetch = lastFetchStr ? parseInt(lastFetchStr, 10) : 0;
      if (now - lastFetch < AI_RECOMMENDATION_FETCH_INTERVAL) {
        const cached = await AsyncStorage.getItem('ai_recommendations_cache');
        if (cached) return JSON.parse(cached);
        return [];
      }

      // Pull recent glucose readings from Redux state (glucose slice)
      const state: any = getState();
      const readings: Array<any> = (state?.glucose?.readings) || [];

      if (!readings || readings.length === 0) {
        console.warn('No local glucose readings available — returning cached or empty recommendations');
        const cached = await AsyncStorage.getItem('ai_recommendations_cache');
        if (cached) {
          await AsyncStorage.setItem('ai_recommendations_last_fetch', now.toString());
          return JSON.parse(cached);
        }
        return [];
      }

      // Simple rule-based generator using most recent readings
      const latest = readings[0];
      const second = readings[1];
      const recentVals = readings.slice(0, 12).map(r => r.value).filter(v => typeof v === 'number'); // ~last hour

      const avgRecent = recentVals.length ? Math.round(recentVals.reduce((a, b) => a + b, 0) / recentVals.length) : null;
      const delta = (latest && second) ? latest.value - second.value : 0; // positive = rising

      const recs: Recommendation[] = [];

      // Rule 1: High glucose
      if (latest.value >= 250) {
        recs.push({
          title: 'High glucose — consider correction',
          description: `Latest reading ${latest.value} mg/dL. Consider correction per your care plan and recheck in 15–30 min.`,
          category: 'safety',
          priority: 'high',
          confidence: 0.9,
          action: 'consider_insulin',
          timing: 'now',
          context: { latest: latest.value, avgRecent },
        });
      } else if (latest.value >= 180) {
        recs.push({
          title: 'Elevated glucose',
          description: `Latest reading ${latest.value} mg/dL. Monitor closely and consider activity or insulin per your plan.`,
          category: 'management',
          priority: 'medium',
          confidence: 0.75,
          action: 'monitor_or_adjust',
          timing: 'short_term',
          context: { latest: latest.value, avgRecent },
        });
      }

      // Rule 2: Low glucose
      if (latest.value <= 70) {
        recs.push({
          title: 'Low glucose — treat now',
          description: `Latest reading ${latest.value} mg/dL. Take 15–20g fast-acting carbs and recheck in 15 minutes.`,
          category: 'safety',
          priority: 'high',
          confidence: 0.95,
          action: 'treat_hypo',
          timing: 'immediate',
          context: { latest: latest.value },
        });
      } else if (latest.value < 90 && delta < -10) {
        recs.push({
          title: 'Dropping glucose',
          description: `Glucose dropping (${delta} mg/dL between latest readings). Be prepared to treat if it continues downward.`,
          category: 'management',
          priority: 'medium',
          confidence: 0.7,
          action: 'prepare_treatment',
          timing: 'immediate',
          context: { latest: latest.value, delta },
        });
      }

      // Rule 3: Rapid rise
      if (delta > 15) {
        recs.push({
          title: 'Rapid rise detected',
          description: `Glucose increased ${delta} mg/dL since last point. Consider carb correction or extra monitoring.`,
          category: 'trend',
          priority: 'medium',
          confidence: 0.8,
          action: 'monitor_or_correct',
          timing: 'short_term',
          context: { latest: latest.value, delta },
        });
      }

      // Rule 4: Time-in-range summary suggestion
      if (avgRecent !== null) {
        if (avgRecent >= 120 && avgRecent < 180) {
          recs.push({
            title: 'Average trending high',
            description: `1-hour average ${avgRecent} mg/dL — consider reviewing meal/insulin timing.`,
            category: 'insight',
            priority: 'low',
            confidence: 0.6,
            action: 'review_patterns',
            timing: 'next_24h',
            context: { avgRecent },
          });
        } else if (avgRecent < 120) {
          recs.push({
            title: 'Average in range',
            description: `1-hour average ${avgRecent} mg/dL — good control recently. Keep up with current plan.`,
            category: 'positive',
            priority: 'low',
            confidence: 0.6,
            action: 'maintain',
            timing: 'ongoing',
            context: { avgRecent },
          });
        }
      }

      // If no rules triggered, provide a gentle prompt
      if (recs.length === 0) {
        recs.push({
          title: 'No immediate actions',
          description: `No concerning glucose patterns in recent data. Keep monitoring.`,
          category: 'info',
          priority: 'low',
          confidence: 0.5,
          action: 'monitor',
          timing: 'ongoing',
          context: { latest: latest.value, avgRecent },
        });
      }

      // Cache and return
      await AsyncStorage.setItem('ai_recommendations_last_fetch', now.toString());
      await AsyncStorage.setItem('ai_recommendations_cache', JSON.stringify(recs));
      return recs;
    } catch (error: any) {
      console.error('Error generating AI recommendations locally:', error?.message || error);
      const cached = await AsyncStorage.getItem('ai_recommendations_cache');
      if (cached) return JSON.parse(cached);
      return rejectWithValue('Failed to generate recommendations');
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
