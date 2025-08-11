import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { Provider as PaperProvider, Snackbar } from 'react-native-paper';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { NavigationContainer } from '@react-navigation/native';

import { store, persistor } from './src/store/store';
import { AppNavigator } from './src/navigation/AppNavigator';
import { LoadingScreen } from './src/components/common/LoadingScreen';
import { theme } from './src/theme/theme';
import { NotificationManager } from './src/services/NotificationManager';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { setToken, setRefreshToken } from './src/store/slices/authSlice';
import { setReduxDispatch } from './src/services/reduxDispatch';


export default function App() {
  const [isRefreshing, setIsRefreshing] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showSnackbar, setShowSnackbar] = useState(false);

  useEffect(() => {
    NotificationManager.initialize();
    setReduxDispatch(store.dispatch);

    // Proactive token refresh on app launch
    const refreshTokenOnLaunch = async () => {
      try {
        const api = (await import('./src/services/api')).default;

        // Batch get tokens
        const [[, storedToken], [, storedRefreshToken]] = await AsyncStorage.multiGet(['auth_token', 'refresh_token']);
        
        // Update Redux state with stored tokens
        if (storedToken) {
          store.dispatch(setToken(storedToken));
          console.log('Restored access token from storage to Redux state');
        }
        
        if (storedRefreshToken) {
          store.dispatch(setRefreshToken(storedRefreshToken));
          console.log('Restored refresh token from storage to Redux state');
          
          try {
            // Attempt to refresh the token on app launch if we have a refresh token
            console.log('Attempting to proactively refresh token on app launch');
            const refreshResponse = await api.post('/api/v1/auth/refresh', {
              refresh_token: storedRefreshToken
            });
            
            const { access_token: newToken, refresh_token: newRefreshToken } = refreshResponse.data;

            if (newToken) {
              // Update both tokens in Redux and storage
              store.dispatch(setToken(newToken));
              
              // Prepare batch operation
              const multiSetArr: [string, string][] = [['auth_token', newToken]];
              
              if (newRefreshToken) {
                store.dispatch(setRefreshToken(newRefreshToken));
                multiSetArr.push(['refresh_token', newRefreshToken]);
                console.log('Updated both access and refresh tokens proactively');
              } else {
                console.log('Updated access token only (no new refresh token returned)');
              }
              
              // Execute batch storage update
              await AsyncStorage.multiSet(multiSetArr);
            }
          } catch (err: any) {
            // Detect expired/invalid token and show user-friendly error
            let message = 'Failed to refresh session. Please try logging out and back in.';
            if (err?.response?.status === 401) {
              message = 'Session expired. Please log out and log in again.';
            }
            setError(message);
            setShowSnackbar(true);
            console.error('Failed to refresh token on app launch:', err);
          }
        } else {
          console.log('No refresh token found in storage, skipping token refresh');
        }
      } catch (e) {
        setError('Unexpected error during startup.');
        setShowSnackbar(true);
        console.error('Error in refreshTokenOnLaunch:', e);
      } finally {
        setIsRefreshing(false);
      }
    };
    refreshTokenOnLaunch();
  }, []);



  // Log tokens after rehydration
  useEffect(() => {
    if (!isRefreshing) {
      (async () => {
        const authToken = await AsyncStorage.getItem('auth_token');
        const refreshToken = await AsyncStorage.getItem('refresh_token');
        const maskedRefreshToken = refreshToken ? (refreshToken.substring(0, 6) + '...' + refreshToken.substring(refreshToken.length - 6)) : null;
        console.log('[API INIT] Auth token:', authToken ? authToken.substring(0, 8) + '...' : null);
        console.log('[API INIT] Refresh token:', maskedRefreshToken);
      })();
    }
  }, [isRefreshing]);

  if (isRefreshing) {
    return <LoadingScreen />;
  }

  return (
    <Provider store={store}>
      <PersistGate loading={<LoadingScreen />} persistor={persistor}>
        <PaperProvider theme={theme}>
          <SafeAreaProvider>
            <NavigationContainer theme={theme}>
              <AppNavigator />
            </NavigationContainer>
            <StatusBar style="auto" />
            <Snackbar
              visible={showSnackbar}
              onDismiss={() => setShowSnackbar(false)}
              duration={6000}
              action={{ label: 'Dismiss', onPress: () => setShowSnackbar(false) }}
            >
              {error}
            </Snackbar>
          </SafeAreaProvider>
        </PaperProvider>
      </PersistGate>
    </Provider>
  );
}
