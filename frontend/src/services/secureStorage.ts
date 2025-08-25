import * as SecureStore from 'expo-secure-store';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

export const secureStorage = {
  async getItem(key: string): Promise<string | null> {
    try {
      if (Platform.OS === 'web') {
        // SecureStore not available on web — use AsyncStorage as fallback
        return await AsyncStorage.getItem(key);
      }
      return await SecureStore.getItemAsync(key);
    } catch (e) {
      return null;
    }
  },
  async setItem(key: string, value: string): Promise<void> {
    try {
      if (Platform.OS === 'web') {
        await AsyncStorage.setItem(key, value);
        return;
      }
      await SecureStore.setItemAsync(key, value, {
        keychainService: 'glucopilot.secure',
      });
    } catch (e) {
      // no-op
    }
  },
  async removeItem(key: string): Promise<void> {
    try {
      if (Platform.OS === 'web') {
        await AsyncStorage.removeItem(key);
        return;
      }
      await SecureStore.deleteItemAsync(key, {
        keychainService: 'glucopilot.secure',
      });
    } catch (e) {
      // no-op
    }
  },
};

export const AUTH_TOKEN_KEY = 'auth_token';
export const REFRESH_TOKEN_KEY = 'refresh_token';

// Dexcom credential keys (stored securely on-device)
export const DEXCOM_USERNAME_KEY = 'dexcom_username';
export const DEXCOM_PASSWORD_KEY = 'dexcom_password';
export const DEXCOM_OUS_KEY = 'dexcom_ous';
