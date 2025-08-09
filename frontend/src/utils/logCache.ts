import AsyncStorage from '@react-native-async-storage/async-storage';

const LOGS_KEY = 'cached_logs';

export async function cacheLog(log) {
  try {
    const existing = await AsyncStorage.getItem(LOGS_KEY);
    const logs = existing ? JSON.parse(existing) : [];
    logs.unshift(log); // add newest first
    await AsyncStorage.setItem(LOGS_KEY, JSON.stringify(logs));
  } catch (e) {
    // handle error
  }
}

export async function getCachedLogs() {
  try {
    const existing = await AsyncStorage.getItem(LOGS_KEY);
    return existing ? JSON.parse(existing) : [];
  } catch (e) {
    return [];
  }
}

export async function clearCachedLogs() {
  await AsyncStorage.removeItem(LOGS_KEY);
}
