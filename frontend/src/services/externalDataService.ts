import { Platform } from 'react-native';
import api from './api';

// Types for MyFitnessPal data
export interface MyFitnessPalFood {
  name: string;
  serving_size: number;
  serving_unit: string;
  calories: number;
  carbs: number;
  protein: number;
  fat: number;
  fiber: number;
  sugar: number;
  timestamp: string;
  meal_type: string;
}

// Types for Apple Health data
export interface HealthKitActivity {
  type: string;
  startDate: string;
  endDate: string;
  duration: number;
  calories: number;
  distance?: number;
  steps?: number;
  heartRate?: number;
}

export interface HealthKitSleep {
  startDate: string;
  endDate: string;
  duration: number;
  quality?: number;
  deepSleepTime?: number;
  remSleepTime?: number;
  lightSleepTime?: number;
}

export interface HealthKitData {
  activities: HealthKitActivity[];
  sleep: HealthKitSleep[];
  steps: { date: string; count: number }[];
  weight?: { date: string; value: number }[];
  heartRate?: { date: string; value: number }[];
}

class ExternalDataService {
  // MyFitnessPal Integration
  
  // Connect to MyFitnessPal account
  async connectMyFitnessPal(username: string, password: string) {
    try {
      const response = await api.post('/auth/myfitnesspal/connect', { username, password });
      return response.data;
    } catch (error) {
      console.error('Error connecting to MyFitnessPal:', error);
      throw error;
    }
  }
  
  // Disconnect MyFitnessPal account
  async disconnectMyFitnessPal() {
    try {
      const response = await api.post('/auth/myfitnesspal/disconnect');
      return response.data;
    } catch (error) {
      console.error('Error disconnecting MyFitnessPal:', error);
      throw error;
    }
  }
  
  // Sync MyFitnessPal data
  async syncMyFitnessPalData() {
    try {
      const response = await api.post('/data/myfitnesspal/sync');
      return response.data;
    } catch (error) {
      console.error('Error syncing MyFitnessPal data:', error);
      throw error;
    }
  }
  
  // Apple Health / Google Fit Integration
  
  // Check if HealthKit is available (iOS only)
  isHealthKitAvailable() {
    return Platform.OS === 'ios';
  }
  
  // Check if Google Fit is available (Android only)
  isGoogleFitAvailable() {
    return Platform.OS === 'android';
  }
  
  // Request HealthKit permissions
  async requestHealthKitPermissions() {
    if (!this.isHealthKitAvailable()) {
      throw new Error('HealthKit is not available on this device');
    }
    
    // Here we would use react-native-health or similar library
    // This is a placeholder that would be replaced with actual implementation
    try {
      console.log('Requesting HealthKit permissions');
      // Simulated success
      return { success: true };
    } catch (error) {
      console.error('Error requesting HealthKit permissions:', error);
      throw error;
    }
  }
  
  // Request Google Fit permissions
  async requestGoogleFitPermissions() {
    if (!this.isGoogleFitAvailable()) {
      throw new Error('Google Fit is not available on this device');
    }
    
    // Here we would use react-native-google-fit or similar library
    // This is a placeholder that would be replaced with actual implementation
    try {
      console.log('Requesting Google Fit permissions');
      // Simulated success
      return { success: true };
    } catch (error) {
      console.error('Error requesting Google Fit permissions:', error);
      throw error;
    }
  }
  
  // Sync health data with the server
  async syncHealthData(data: HealthKitData) {
    try {
      const response = await api.post('/data/health/sync', data);
      return response.data;
    } catch (error) {
      console.error('Error syncing health data:', error);
      throw error;
    }
  }
  
  // Fetch data insights that incorporate external data
  async getDataInsights() {
    try {
      const response = await api.get('/data/insights');
      return response.data;
    } catch (error) {
      console.error('Error fetching data insights:', error);
      throw error;
    }
  }
}

export const externalDataService = new ExternalDataService();
