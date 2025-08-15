import * as AppleAuthentication from 'expo-apple-authentication';
import api, { setAuthTokens } from './api';
import { secureStorage, AUTH_TOKEN_KEY, REFRESH_TOKEN_KEY } from './secureStorage';
import { Alert } from 'react-native';

/**
 * Perform Sign in with Apple and exchange the identity token with backend /auth/social-login
 * Returns the user profile and tokens on success.
 */
export async function signInWithApple(): Promise<{ user: any; accessToken: string; refreshToken: string } | null> {
  try {
    // Trigger native Apple sign-in
    const credential = await AppleAuthentication.signInAsync({
      requestedScopes: [
        AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
        AppleAuthentication.AppleAuthenticationScope.EMAIL,
      ],
    });

    const identityToken = (credential as any).identityToken;
    const email = (credential as any).email || ((credential as any).fullName ? undefined : undefined);
    const fullName = (credential as any).fullName;

    if (!identityToken) {
      Alert.alert('Apple Sign-In failed', 'No identity token returned.');
      return null;
    }

    // Exchange with backend social login
    const payload: any = {
      first_name: fullName?.givenName || '',
      last_name: fullName?.familyName || '',
      email: email || '',
      provider: 'apple',
      id_token: identityToken,
    };

    const res = await api.post('/auth/social-login', payload);

    const accessToken = res.data.access_token;
    const refreshToken = res.data.refresh_token;

    if (!accessToken || !refreshToken) {
      throw new Error('Missing tokens from social-login response');
    }

    // Persist tokens and seed in-memory cache
    setAuthTokens(accessToken, refreshToken);
    await secureStorage.setItem(AUTH_TOKEN_KEY, accessToken);
    await secureStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);

    // Optionally fetch current user profile
    const userRes = await api.get('/auth/me', { headers: { Authorization: `Bearer ${accessToken}` } });

    return { user: userRes.data, accessToken, refreshToken };
  } catch (err: any) {
    // Distinguish user cancellation vs failure
    if (err.code === 'ERR_CANCELED' || err.message?.toLowerCase?.().includes('canceled') || err.message?.toLowerCase?.().includes('cancelled')) {
      return null; // user cancelled
    }
    console.error('Apple sign-in error:', err);
    Alert.alert('Apple Sign-In error', err?.message || 'An error occurred during Apple Sign-In');
    throw err;
  }
}
