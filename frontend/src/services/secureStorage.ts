import * as SecureStore from 'expo-secure-store';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

const SECURESTORE_KEY_REGEX = /^[A-Za-z0-9._-]+$/;

export const secureStorage = {
  async getItem(key: string): Promise<string | null> {
    try {
      console.log(`[secureStorage] getItem key=${key} platform=${Platform.OS}`);
      if (Platform.OS === 'web') {
        // Try AsyncStorage first (may not be available in all web setups), then fallback to localStorage
        try {
          const v = await AsyncStorage.getItem(key);
          console.log(`[secureStorage] AsyncStorage.getItem for ${key}: ${v ? 'present' : 'null'}`);
          if (v !== null && v !== undefined) return v;
        } catch (e) {
          console.warn('[secureStorage] AsyncStorage.getItem failed on web, falling back to localStorage', e);
        }
        try {
          const v2 = (typeof window !== 'undefined' && window.localStorage) ? window.localStorage.getItem(key) : null;
          console.log(`[secureStorage] localStorage.getItem for ${key}: ${v2 ? 'present' : 'null'}`);
          return v2;
        } catch (e) {
          console.error('[secureStorage] localStorage.getItem error', e);
          return null;
        }
      }

      // Native platforms: prefer SecureStore but don't use it for keys that contain invalid chars
      if (!SECURESTORE_KEY_REGEX.test(key)) {
        console.warn(`[secureStorage] key contains unsupported characters for SecureStore; using AsyncStorage fallback for key=${key}`);
        try {
          const v2 = await AsyncStorage.getItem(key);
          console.log(`[secureStorage] AsyncStorage.getItem fallback for ${key}: ${v2 ? 'present' : 'null'}`);
          return v2;
        } catch (asyncErr) {
          console.error('[secureStorage] AsyncStorage.getItem fallback error', asyncErr);
          return null;
        }
      }

      try {
        const v = await SecureStore.getItemAsync(key, { keychainService: 'glucopilot.secure' });
        console.log(`[secureStorage] getItem result for ${key}: ${v ? 'present' : 'null'}`);
        return v;
      } catch (secureErr) {
        console.warn('[secureStorage] SecureStore.getItemAsync failed unexpectedly, falling back to AsyncStorage', secureErr);
        try {
          const v2 = await AsyncStorage.getItem(key);
          console.log(`[secureStorage] AsyncStorage.getItem fallback for ${key}: ${v2 ? 'present' : 'null'}`);
          return v2;
        } catch (asyncErr) {
          console.error('[secureStorage] AsyncStorage.getItem fallback error', asyncErr);
          return null;
        }
      }
    } catch (e) {
      console.error('[secureStorage] getItem error for', key, e);
      return null;
    }
  },
  async setItem(key: string, value: string): Promise<void> {
    try {
      console.log(`[secureStorage] setItem key=${key} platform=${Platform.OS}`);
      // Avoid printing secret values
      if (Platform.OS === 'web') {
        try {
          await AsyncStorage.setItem(key, value);
          console.log(`[secureStorage] AsyncStorage.setItem completed (web) for ${key}`);
          return;
        } catch (e) {
          console.warn('[secureStorage] AsyncStorage.setItem failed on web, falling back to localStorage', e);
        }
        try {
          if (typeof window !== 'undefined' && window.localStorage) {
            window.localStorage.setItem(key, value);
            console.log(`[secureStorage] localStorage.setItem completed for ${key}`);
            return;
          }
        } catch (e) {
          console.error('[secureStorage] localStorage.setItem error', e);
        }
        // If both attempts failed, throw to be caught below
        throw new Error('Failed to persist to web storage');
      }

      // Native: avoid SecureStore when key contains unsupported chars
      if (!SECURESTORE_KEY_REGEX.test(key)) {
        console.warn(`[secureStorage] key contains unsupported characters for SecureStore; using AsyncStorage fallback for key=${key}`);
        try {
          await AsyncStorage.setItem(key, value);
          console.log(`[secureStorage] AsyncStorage.setItem fallback completed for ${key}`);
          return;
        } catch (asyncErr) {
          console.error('[secureStorage] AsyncStorage.setItem fallback error', asyncErr);
          // no-op
        }
        return;
      }

      try {
        await SecureStore.setItemAsync(key, value, {
          keychainService: 'glucopilot.secure',
        });
        console.log(`[secureStorage] SecureStore.setItemAsync completed for ${key}`);
        return;
      } catch (secureErr) {
        console.warn('[secureStorage] SecureStore.setItemAsync failed unexpectedly, attempting AsyncStorage fallback', secureErr);
        try {
          await AsyncStorage.setItem(key, value);
          console.log(`[secureStorage] AsyncStorage.setItem fallback completed for ${key}`);
          return;
        } catch (asyncErr) {
          console.error('[secureStorage] AsyncStorage.setItem fallback error', asyncErr);
          // no-op
        }
      }
    } catch (e) {
      console.error('[secureStorage] setItem error for', key, e);
      // no-op
    }
  },
  async removeItem(key: string): Promise<void> {
    try {
      console.log(`[secureStorage] removeItem key=${key} platform=${Platform.OS}`);
      if (Platform.OS === 'web') {
        try {
          await AsyncStorage.removeItem(key);
          console.log(`[secureStorage] AsyncStorage.removeItem completed (web) for ${key}`);
          return;
        } catch (e) {
          console.warn('[secureStorage] AsyncStorage.removeItem failed on web, falling back to localStorage', e);
        }
        try {
          if (typeof window !== 'undefined' && window.localStorage) {
            window.localStorage.removeItem(key);
            console.log(`[secureStorage] localStorage.removeItem completed for ${key}`);
            return;
          }
        } catch (e) {
          console.error('[secureStorage] localStorage.removeItem error', e);
        }
        return;
      }

      // Native: avoid SecureStore when key contains unsupported chars
      if (!SECURESTORE_KEY_REGEX.test(key)) {
        console.warn(`[secureStorage] key contains unsupported characters for SecureStore; using AsyncStorage fallback for key=${key}`);
        try {
          await AsyncStorage.removeItem(key);
          console.log(`[secureStorage] AsyncStorage.removeItem fallback completed for ${key}`);
          return;
        } catch (asyncErr) {
          console.error('[secureStorage] AsyncStorage.removeItem fallback error', asyncErr);
        }
        return;
      }

      try {
        await SecureStore.deleteItemAsync(key, {
          keychainService: 'glucopilot.secure',
        });
        console.log(`[secureStorage] SecureStore.deleteItemAsync completed for ${key}`);
        return;
      } catch (secureErr) {
        console.warn('[secureStorage] SecureStore.deleteItemAsync failed unexpectedly, attempting AsyncStorage fallback', secureErr);
        try {
          await AsyncStorage.removeItem(key);
          console.log(`[secureStorage] AsyncStorage.removeItem fallback completed for ${key}`);
          return;
        } catch (asyncErr) {
          console.error('[secureStorage] AsyncStorage.removeItem fallback error', asyncErr);
        }
      }
    } catch (e) {
      console.error('[secureStorage] removeItem error for', key, e);
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

// Debug helper to inspect Dexcom keys without exposing full secrets
export async function debugDumpDexcom() {
  try {
    const user = await secureStorage.getItem(DEXCOM_USERNAME_KEY);
    const pass = await secureStorage.getItem(DEXCOM_PASSWORD_KEY);
    const ous = await secureStorage.getItem(DEXCOM_OUS_KEY);
    const maskedUser = user ? `${user.slice(0,3)}***` : null;
    console.log('[secureStorage][debugDumpDexcom]', { hasUser: !!user, hasPass: !!pass, maskedUser, ous });
    return { hasUser: !!user, hasPass: !!pass, maskedUser, ous };
  } catch (e) {
    console.error('[secureStorage][debugDumpDexcom] error', e);
    return { hasUser: false, hasPass: false, maskedUser: null, ous: null };
  }
}
