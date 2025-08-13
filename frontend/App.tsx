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
import { secureStorage, AUTH_TOKEN_KEY, REFRESH_TOKEN_KEY } from './src/services/secureStorage';
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

        // Read tokens from secure storage
        const storedToken = await secureStorage.getItem(AUTH_TOKEN_KEY);
        const storedRefreshToken = await secureStorage.getItem(REFRESH_TOKEN_KEY);
        
        // Update Redux state with stored tokens
        if (storedToken) {
          store.dispatch(setToken(storedToken));
        }
        
        if (storedRefreshToken) {
          store.dispatch(setRefreshToken(storedRefreshToken));
          
          try {
            // Attempt to refresh the token on app launch if we have a refresh token
            const refreshResponse = await api.post('/api/v1/auth/refresh', {
              refresh_token: storedRefreshToken
            });
            
            const { access_token: newToken, refresh_token: newRefreshToken } = refreshResponse.data;

            if (newToken) {
              // Update both tokens in Redux and storage
              store.dispatch(setToken(newToken));
              
              if (newRefreshToken) {
                store.dispatch(setRefreshToken(newRefreshToken));
              }
              await secureStorage.setItem(AUTH_TOKEN_KEY, newToken);
              await secureStorage.setItem(REFRESH_TOKEN_KEY, newRefreshToken || storedRefreshToken);
            }
          } catch (err: any) {
            // Detect expired/invalid token and show user-friendly error
            let message = 'Failed to refresh session. Please try logging out and back in.';
            if (err?.response?.status === 401) {
              message = 'Session expired. Please log out and log in again.';
            }
            setError(message);
            setShowSnackbar(true);
          }
        } else {
          console.log('No refresh token found in storage, skipping token refresh');
        }
      } catch (e) {
        setError('Unexpected error during startup.');
        setShowSnackbar(true);
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
        // No token logging
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
