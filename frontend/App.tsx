import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { Provider as PaperProvider } from 'react-native-paper';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { NavigationContainer } from '@react-navigation/native';

import { store, persistor } from './src/store/store';
import { AppNavigator } from './src/navigation/AppNavigator';
import { LoadingScreen } from './src/components/common/LoadingScreen';
import { theme } from './src/theme/theme';
import { NotificationManager } from './src/services/NotificationManager';


export default function App() {
  const [isRefreshing, setIsRefreshing] = useState(true);

  useEffect(() => {
    // Initialize notification manager
    NotificationManager.initialize();

    // Proactive token refresh on app launch
    const refreshTokenOnLaunch = async () => {
      try {
        const refreshToken = await import('./src/services/api').then(m => m.default);
        const AsyncStorage = (await import('@react-native-async-storage/async-storage')).default;
        const api = (await import('./src/services/api')).default;
        const { setToken } = await import('./src/store/slices/authSlice');
        const { setReduxDispatch } = await import('./src/services/reduxDispatch');

        const storedRefreshToken = await AsyncStorage.getItem('refresh_token');
        if (storedRefreshToken) {
          try {
            const refreshResponse = await api.post('/auth/refresh', { refresh_token: storedRefreshToken });
            const { access_token: newToken, refresh_token: newRefreshToken } = refreshResponse.data;
            if (newToken) {
              await AsyncStorage.setItem('auth_token', newToken);
              setReduxDispatch(setToken(newToken));
              if (newRefreshToken) {
                await AsyncStorage.setItem('refresh_token', newRefreshToken);
              }
            }
          } catch (err) {
            // If refresh fails, clear tokens
            await AsyncStorage.removeItem('auth_token');
            await AsyncStorage.removeItem('refresh_token');
          }
        }
      } catch (e) {
        // Ignore errors
      } finally {
        setIsRefreshing(false);
      }
    };
    refreshTokenOnLaunch();
  }, []);

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
          </SafeAreaProvider>
        </PaperProvider>
      </PersistGate>
    </Provider>
  );
}
