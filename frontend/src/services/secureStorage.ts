import * as Keychain from 'react-native-keychain';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

const SECURESTORE_KEY_REGEX = /^[A-Za-z0-9._-]+$/;
const SERVICE_NAME = 'glucopilot.secure';

export const secureStorage = {
  async getItem(key: string): Promise<string | null> {
    try {
      console.log(`[secureStorage] getItem key=${key} platform=${Platform.OS}`);
      
      // For web, use AsyncStorage only since keychain is not available
      if (Platform.OS === 'web') {
        try {
          const v = await AsyncStorage.getItem(key);
          console.log(`[secureStorage] AsyncStorage.getItem for ${key}: ${v ? 'present' : 'null'}`);
          return v;
        } catch (e) {
          console.error('[secureStorage] AsyncStorage.getItem error on web', e);
          return null;
        }
      }

      // Native platforms: prefer Keychain but fallback to AsyncStorage for problematic keys
      if (!SECURESTORE_KEY_REGEX.test(key)) {
        console.warn(`[secureStorage] key contains unsupported characters for Keychain; using AsyncStorage fallback for key=${key}`);
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
        const credentials = await Keychain.getInternetCredentials(key);
        if (credentials && credentials.password) {
          console.log(`[secureStorage] getItem result for ${key}: present`);
          return credentials.password;
        } else {
          console.log(`[secureStorage] getItem result for ${key}: null`);
          return null;
        }
      } catch (keychainErr) {
        console.warn('[secureStorage] Keychain.getInternetCredentials failed unexpectedly, falling back to AsyncStorage', keychainErr);
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
      
      // For web, use AsyncStorage only
      if (Platform.OS === 'web') {
        try {
          await AsyncStorage.setItem(key, value);
          console.log(`[secureStorage] AsyncStorage.setItem completed (web) for ${key}`);
          return;
        } catch (e) {
          console.error('[secureStorage] AsyncStorage.setItem error on web', e);
          throw e;
        }
      }

      // Native: avoid Keychain when key contains unsupported chars
      if (!SECURESTORE_KEY_REGEX.test(key)) {
        console.warn(`[secureStorage] key contains unsupported characters for Keychain; using AsyncStorage fallback for key=${key}`);
        try {
          await AsyncStorage.setItem(key, value);
          console.log(`[secureStorage] AsyncStorage.setItem fallback completed for ${key}`);
          return;
        } catch (asyncErr) {
          console.error('[secureStorage] AsyncStorage.setItem fallback error', asyncErr);
          return;
        }
      }

      try {
        await Keychain.setInternetCredentials(key, key, value);
        console.log(`[secureStorage] Keychain.setInternetCredentials completed for ${key}`);
        return;
      } catch (keychainErr) {
        console.warn('[secureStorage] Keychain.setInternetCredentials failed unexpectedly, attempting AsyncStorage fallback', keychainErr);
        try {
          await AsyncStorage.setItem(key, value);
          console.log(`[secureStorage] AsyncStorage.setItem fallback completed for ${key}`);
          return;
        } catch (asyncErr) {
          console.error('[secureStorage] AsyncStorage.setItem fallback error', asyncErr);
        }
      }
    } catch (e) {
      console.error('[secureStorage] setItem error for', key, e);
    }
  },

  async removeItem(key: string): Promise<void> {
    try {
      console.log(`[secureStorage] removeItem key=${key} platform=${Platform.OS}`);
      
      // For web, use AsyncStorage only
      if (Platform.OS === 'web') {
        try {
          await AsyncStorage.removeItem(key);
          console.log(`[secureStorage] AsyncStorage.removeItem completed (web) for ${key}`);
          return;
        } catch (e) {
          console.error('[secureStorage] AsyncStorage.removeItem error on web', e);
          return;
        }
      }

      // Native: avoid Keychain when key contains unsupported chars
      if (!SECURESTORE_KEY_REGEX.test(key)) {
        console.warn(`[secureStorage] key contains unsupported characters for Keychain; using AsyncStorage fallback for key=${key}`);
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
        await Keychain.resetInternetCredentials(key);
        console.log(`[secureStorage] Keychain.resetInternetCredentials completed for ${key}`);
        return;
      } catch (keychainErr) {
        console.warn('[secureStorage] Keychain.resetInternetCredentials failed unexpectedly, attempting AsyncStorage fallback', keychainErr);
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
