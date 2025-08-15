import { Platform } from 'react-native';
import api from './api';
import AppleHealthKit from 'react-native-health';

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
  // MyFitnessPal Integration (frontend hooks call backend)

  // Connect to MyFitnessPal account - frontend proxy to backend
  async connectMyFitnessPal(username: string, password: string) {
    const response = await api.post('/auth/myfitnesspal/connect', { username, password });
    return response.data;
  }

  // Disconnect MyFitnessPal account
  async disconnectMyFitnessPal() {
    const response = await api.post('/auth/myfitnesspal/disconnect');
    return response.data;
  }

  // Sync MyFitnessPal data (trigger backend sync)
  async syncMyFitnessPalData(startDate?: string, endDate?: string) {
    const payload: any = {};
    if (startDate) payload.start_date = startDate;
    if (endDate) payload.end_date = endDate;
    const response = await api.post('/data/myfitnesspal/sync', payload);
    return response.data;
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

  // Internal helper: initialize HealthKit with read permissions
  private async initHealthKit() {
    if (!this.isHealthKitAvailable()) {
      throw new Error('HealthKit is not available on this device');
    }

    const options = {
      permissions: {
        read: [
          AppleHealthKit.Constants?.Permissions?.StepCount,
          AppleHealthKit.Constants?.Permissions?.HeartRate,
          AppleHealthKit.Constants?.Permissions?.DistanceWalkingRunning,
          AppleHealthKit.Constants?.Permissions?.SleepAnalysis,
          AppleHealthKit.Constants?.Permissions?.Weight,
        ].filter(Boolean),
        write: [],
      },
    } as any;

    // Support different native bridge method names (initHealthKit, initializeHealthKit, initialize)
    const initFn = (AppleHealthKit as any).initHealthKit || (AppleHealthKit as any).initializeHealthKit || (AppleHealthKit as any).initialize;

    if (typeof initFn === 'function') {
      return new Promise<void>((resolve, reject) => {
        try {
          initFn.call(AppleHealthKit, options, (err: string | null) => {
            if (err) return reject(new Error(`HealthKit init error: ${err}`));
            resolve();
          });
        } catch (e) {
          reject(e);
        }
      });
    }

    // If there is no init method, surface a clear error with available keys to help debugging
    const keys = Object.keys(AppleHealthKit || {}).slice(0, 50).join(', ');
    // Provide actionable guidance for common Expo-managed workflow issue
    throw new Error(
      `AppleHealthKit bridge does not expose an init method. Available keys: ${keys}. ` +
      `This usually means the native HealthKit module isn't linked into the running app (common when using Expo Go). ` +
      `Build a custom dev client or run the app from Xcode (prebuild / eject) so the native module is present, then try again.`
    );
  }

  // Request HealthKit permissions (exposed)
  async requestHealthKitPermissions() {
    if (!this.isHealthKitAvailable()) {
      throw new Error('HealthKit is not available on this device');
    }

    try {
      await this.initHealthKit();
      return { success: true };
    } catch (error) {
      console.error('Error requesting HealthKit permissions:', error);
      throw error;
    }
  }

  // Fetch health data between two ISO date strings (inclusive)
  async fetchHealthData(startDateISO: string, endDateISO: string): Promise<HealthKitData> {
    if (!this.isHealthKitAvailable()) {
      throw new Error('HealthKit is not available on this device');
    }

    // Ensure HealthKit initialized
    await this.initHealthKit();

    const HK: any = AppleHealthKit;

    const startDate = new Date(startDateISO).toISOString();
    const endDate = new Date(endDateISO).toISOString();

    // Helper to promisify callback-style calls
    const toPromise = (fn: Function, args: any) => new Promise<any>((res, rej) => {
      try {
        fn(args, (err: any, result: any) => {
          if (err) return rej(err);
          return res(result);
        });
      } catch (e) {
        rej(e);
      }
    });

    // Read steps per day
    let steps: any[] = [];
    try {
      const opts = { startDate, endDate } as any;
      if (typeof HK.getDailyStepCountSamples === 'function') {
        const daily = await toPromise(HK.getDailyStepCountSamples, opts) as any;
        // normalize to { date, count }
        if (Array.isArray(daily)) {
          steps = daily.map((s: any) => ({ date: s.startDate || s.day || s.date, count: s.value || s.steps || s.count }));
        }
      } else if (typeof HK.getStepCount === 'function') {
        const result = await toPromise(HK.getStepCount, { startDate, endDate }) as any;
        steps = [{ date: startDateISO, count: (result && (result.value ?? result)) || 0 }];
      }
    } catch (err) {
      console.warn('Failed to read steps from HealthKit:', err);
    }

    // Read distance/activity (distance walking/running)
    let activities: HealthKitActivity[] = [];
    try {
      if (typeof HK.getDistanceWalkingRunning === 'function') {
        const distances = await toPromise(HK.getDistanceWalkingRunning, { startDate, endDate }) as any;
        // distances may be an array or single object
        const items = Array.isArray(distances) ? distances : (distances ? [distances] : []);
        activities = items.map((d: any) => ({
          type: 'walking_running',
          startDate: d.startDate || startDate,
          endDate: d.endDate || endDate,
          duration: (new Date(d.endDate || endDate).getTime() - new Date(d.startDate || startDate).getTime()) / 1000,
          calories: d.energy ? d.energy : 0,
          distance: d.value || d.distance || d.quantity || 0,
          steps: d.steps || undefined,
        }));
      }
    } catch (err) {
      console.warn('Failed to read distance/activity from HealthKit:', err);
    }

    // Read sleep samples
    let sleep: HealthKitSleep[] = [];
    try {
      if (typeof HK.getSleepSamples === 'function') {
        const sl = await toPromise(HK.getSleepSamples, { startDate, endDate, limit: 1000 }) as any;
        if (Array.isArray(sl)) {
          sleep = sl.map((s: any) => ({
            startDate: s.startDate,
            endDate: s.endDate,
            duration: (new Date(s.endDate).getTime() - new Date(s.startDate).getTime()) / 1000,
          }));
        }
      }
    } catch (err) {
      console.warn('Failed to read sleep from HealthKit:', err);
    }

    // Read weight samples
    let weight: { date: string; value: number }[] = [];
    try {
      if (typeof HK.getWeightSamples === 'function') {
        const w = await toPromise(HK.getWeightSamples, { startDate, endDate, unit: 'kg', limit: 100 }) as any;
        if (Array.isArray(w)) {
          weight = w.map((x: any) => ({ date: x.startDate || x.date, value: x.value || x.quantity }));
        }
      }
    } catch (err) {
      console.warn('Failed to read weight from HealthKit:', err);
    }

    // Read heart rate samples
    let heartRate: { date: string; value: number }[] = [];
    try {
      if (typeof HK.getHeartRateSamples === 'function') {
        const hr = await toPromise(HK.getHeartRateSamples, { startDate, endDate, limit: 100 }) as any;
        if (Array.isArray(hr)) {
          heartRate = hr.map((h: any) => ({ date: h.startDate || h.date, value: h.value || h.quantity }));
        }
      }
    } catch (err) {
      console.warn('Failed to read heart rate from HealthKit:', err);
    }

    const data: HealthKitData = {
      activities,
      sleep,
      steps,
      weight: weight.length ? weight : undefined,
      heartRate: heartRate.length ? heartRate : undefined,
    };

    return data;
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
